import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../children_store.dart';
import '../document_storage.dart';
import '../expenses_store.dart';
import '../fee_types_store.dart';
import '../settings_store.dart';
import 'sync_models.dart';

enum SyncRunStatus { idle, syncing, success, failed }

/// Orchestrates exporting, merging, conflict resolution, and store refresh.
class SyncService extends ChangeNotifier {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  static const syncTables = [
    'children',
    'guardians',
    'documents',
    'attendance',
    'payments',
    'expenses',
    'fee_types',
    'fee_rates',
  ];

  List<SyncConflict> _conflicts = [];
  SyncRunStatus _runStatus = SyncRunStatus.idle;
  String? _lastError;

  List<SyncConflict> get conflicts => List.unmodifiable(_conflicts);
  SyncRunStatus get runStatus => _runStatus;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => SettingsStore.instance.lastSyncTime;

  bool get isRecentlySynced {
    final t = lastSyncTime;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(minutes: 5);
  }

  Future<void> init() async {
    await loadConflicts();
  }

  Future<void> loadConflicts() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('sync_conflicts', orderBy: 'created_at DESC');
    _conflicts = rows.map(SyncConflict.fromMap).toList();
    notifyListeners();
  }

  Future<SyncPayload> exportChanges({DateTime? since}) async {
    final db = await AppDatabase.instance.database;
    final tables = <String, List<Map<String, dynamic>>>{};
    final isMobile = !SettingsStore.instance.isDesktop;

    for (final table in syncTables) {
      final rows = since == null
          ? await db.query(table)
          : await db.query(
              table,
              where: 'updated_at > ?',
              whereArgs: [since.toIso8601String()],
            );
      tables[table] = rows
          .map((r) => _prepareRowForExport(table, Map<String, dynamic>.from(r), isMobile))
          .toList();
    }

    return SyncPayload(
      deviceId: SettingsStore.instance.deviceId,
      timestamp: DateTime.now(),
      tables: tables,
    );
  }

  Map<String, dynamic> _prepareRowForExport(
    String table,
    Map<String, dynamic> row,
    bool isMobile,
  ) {
    if (table == 'documents') {
      row.remove('file_path');
      if (isMobile) row.remove('printed');
    }
    return row;
  }

  Future<ImportResult> importChanges(SyncPayload payload) async {
    final db = await AppDatabase.instance.database;
    var conflictCount = 0;
    final missingHashes = <String>{};
    final isDesktop = SettingsStore.instance.isDesktop;
    final localDeviceId = SettingsStore.instance.deviceId;

    await db.transaction((txn) async {
      for (final entry in payload.tables.entries) {
        final table = entry.key;
        final rows = entry.value;

        for (final rawRow in rows) {
          final row = Map<String, dynamic>.from(rawRow);
          final id = row['id'] as String?;
          if (id == null) continue;

          final existing = await txn.query(table, where: 'id = ?', whereArgs: [id]);

          if (table == 'payments') {
            if (existing.isNotEmpty &&
                _paymentConflict(existing.first, row)) {
              await _recordConflict(txn, table, id, existing.first, row);
              conflictCount++;
              continue;
            }
          } else if (existing.isNotEmpty && !_remoteWins(existing.first, row)) {
            continue;
          }

          if (table == 'documents') {
            _applyDocumentImportRules(
              row: row,
              existing: existing,
              fromRemote: payload.deviceId != localDeviceId,
              isDesktop: isDesktop,
            );
            final hash = row['sha256'] as String?;
            if (hash != null && hash.isNotEmpty) {
              final hasLocal = await DocumentStorage.hasBytesForHash(hash);
              if (!hasLocal) missingHashes.add(hash);
            }
          }

          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          if (table == 'documents') {
            final hash = row['sha256'] as String?;
            if (hash != null && hash.isNotEmpty) {
              final path = await DocumentStorage.localPathForHash(hash);
              if (path != null) {
                await txn.update(
                  'documents',
                  {'file_path': path},
                  where: 'id = ?',
                  whereArgs: [id],
                );
              }
            }
          }
        }
      }
    });

    await ChildrenStore.instance.init();
    await ExpensesStore.instance.init();
    await FeeTypesStore.instance.init();
    await loadConflicts();
    notifyListeners();

    return ImportResult(
      conflictCount: conflictCount,
      missingHashes: missingHashes.toList(),
    );
  }

  bool _paymentConflict(Map<String, dynamic> local, Map<String, dynamic> remote) {
    return local['status'] != remote['status'] || local['amount'] != remote['amount'];
  }

  bool _remoteWins(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localAt = DateTime.tryParse(local['updated_at'] as String? ?? '');
    final remoteAt = DateTime.tryParse(remote['updated_at'] as String? ?? '');
    if (remoteAt == null) return false;
    if (localAt == null) return true;
    return !remoteAt.isBefore(localAt);
  }

  void _applyDocumentImportRules({
    required Map<String, dynamic> row,
    required List<Map<String, dynamic>> existing,
    required bool fromRemote,
    required bool isDesktop,
  }) {
    row.remove('file_path');
    if (existing.isEmpty) {
      if (fromRemote && row['type'] == 'registration') {
        row['printed'] = 0;
      } else {
        row['printed'] = 1;
      }
      return;
    }
    if (fromRemote && isDesktop) {
      row['printed'] = existing.first['printed'];
    }
  }

  Future<void> _recordConflict(
    DatabaseExecutor txn,
    String table,
    String entityId,
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) async {
    final conflict = SyncConflict(
      id: const Uuid().v4(),
      tableName: table,
      entityId: entityId,
      localData: local,
      remoteData: remote,
      createdAt: DateTime.now(),
    );
    await txn.insert('sync_conflicts', conflict.toMap());
  }

  Future<void> resolveConflict(SyncConflict conflict, {required bool keepLocal}) async {
    final db = await AppDatabase.instance.database;
    final targetData = keepLocal ? conflict.localData : conflict.remoteData;

    await db.transaction((txn) async {
      await txn.insert(
        conflict.tableName,
        targetData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('sync_conflicts', where: 'id = ?', whereArgs: [conflict.id]);
    });

    await ChildrenStore.instance.init();
    await loadConflicts();
  }

  Future<void> markDocumentPrinted(String documentId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'documents',
      {'printed': 1, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [documentId],
    );
    await ChildrenStore.instance.init();
    notifyListeners();
  }

  Future<int> unprintedRegistrationCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM documents WHERE type = 'registration' AND printed = 0",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<({String childName, String childInitials, ChildDocumentRow doc})>>
      unprintedRegistrations() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT d.*, c.first_name, c.last_name
      FROM documents d
      JOIN children c ON c.id = d.child_id
      WHERE d.type = 'registration' AND d.printed = 0
      ORDER BY d.uploaded_at DESC
    ''');
    return rows.map((row) {
      final first = row['first_name'] as String;
      final last = row['last_name'] as String;
      return (
        childName: '$first $last',
        childInitials: '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
            .toUpperCase(),
        doc: ChildDocumentRow.fromMap(row),
      );
    }).toList();
  }

  Future<void> setRunStatus(SyncRunStatus status, {String? error}) async {
    _runStatus = status;
    _lastError = error;
    notifyListeners();
  }

  Future<void> recordSuccessfulSync() async {
    await SettingsStore.instance.setLastSyncTime(DateTime.now());
    await setRunStatus(SyncRunStatus.success);
  }

  Future<void> markChildrenSynced(Iterable<String> childIds) async {
    if (childIds.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    for (final id in childIds) {
      await db.update(
        'children',
        {'synced': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<String>> hashesNeedingDownload() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'documents',
      columns: ['sha256'],
      where: "sha256 IS NOT NULL AND sha256 != ''",
    );
    final missing = <String>[];
    for (final row in rows) {
      final hash = row['sha256'] as String?;
      if (hash == null || hash.isEmpty) continue;
      if (!await DocumentStorage.hasBytesForHash(hash)) {
        missing.add(hash);
      }
    }
    return missing;
  }

  Future<List<String>> hashesAvailableForUpload() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'documents',
      where: "sha256 IS NOT NULL AND sha256 != ''",
    );
    final hashes = <String>[];
    for (final row in rows) {
      final hash = row['sha256'] as String?;
      final path = row['file_path'] as String?;
      if (hash == null || hash.isEmpty || path == null || path.isEmpty) continue;
      if (await DocumentStorage.verify(path: path, expectedSha256: hash)) {
        hashes.add(hash);
      }
    }
    return hashes;
  }

  Future<void> attachDownloadedFile(String hash, String path) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'documents',
      {'file_path': path},
      where: 'sha256 = ?',
      whereArgs: [hash],
    );
    await ChildrenStore.instance.init();
  }
}

class ImportResult {
  final int conflictCount;
  final List<String> missingHashes;

  const ImportResult({
    required this.conflictCount,
    required this.missingHashes,
  });
}

/// Lightweight document row for the print queue (avoids pulling full Child).
class ChildDocumentRow {
  final String id;
  final String childId;
  final String label;
  final String type;
  final DateTime uploadedAt;
  final String? filePath;
  final String? sha256;

  const ChildDocumentRow({
    required this.id,
    required this.childId,
    required this.label,
    required this.type,
    required this.uploadedAt,
    this.filePath,
    this.sha256,
  });

  factory ChildDocumentRow.fromMap(Map<String, dynamic> map) => ChildDocumentRow(
        id: map['id'] as String,
        childId: map['child_id'] as String,
        label: map['label'] as String,
        type: map['type'] as String,
        uploadedAt: DateTime.parse(map['uploaded_at'] as String),
        filePath: map['file_path'] as String?,
        sha256: map['sha256'] as String?,
      );
}

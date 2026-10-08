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

/// The merge engine shared by both apps.
///
/// Desktop is the source of truth and runs the HTTP server; mobile is a
/// client. Neither the roles nor the wire protocol change what happens to
/// a row once it arrives: the same [importChanges] runs on both sides.
///
/// Merge rules, per incoming row:
///  * unknown id → insert.
///  * identical content → nothing to do.
///  * `payments` that **both** sides changed since the last sync → don't
///    overwrite either; record a row in `sync_conflicts` for a human.
///  * everything else → newest `updated_at` wins (ties keep what's local).
///
/// `documents.printed` is owned by desktop and is never accepted from
/// mobile, so it can't conflict.
class SyncService extends ChangeNotifier {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  /// Parents before children — inserts happen in this order so foreign
  /// keys are satisfied.
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

  /// Phone and desktop clocks are never perfectly aligned. Pulls look back
  /// this much further than the last sync time; re-seeing a row is
  /// harmless because identical or older rows are skipped.
  static const clockSkewOverlap = Duration(minutes: 2);

  List<SyncConflict> _conflicts = [];
  SyncRunStatus _runStatus = SyncRunStatus.idle;
  String? _lastError;
  final Map<String, Set<String>> _columnCache = {};

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

  // ---------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------

  /// Rows created or edited since [since] (everything when null), across
  /// all tables.
  ///
  /// [excludeIds] lists rows to leave out (`table -> ids`): the caller
  /// passes the rows it just received so they aren't echoed back. Rows
  /// with an unresolved conflict on this side are always left out so the
  /// other side isn't asked to re-judge something already waiting for a
  /// human decision here.
  Future<SyncPayload> exportChanges({
    DateTime? since,
    Map<String, Set<String>> excludeIds = const {},
  }) async {
    final db = await AppDatabase.instance.database;
    final tables = <String, List<Map<String, dynamic>>>{};
    final isDesktop = SettingsStore.instance.isDesktop;
    final cutoff = since?.subtract(clockSkewOverlap).toIso8601String();

    final conflictRows = await db.query('sync_conflicts');
    final conflicted = <String, Set<String>>{};
    for (final c in conflictRows) {
      conflicted
          .putIfAbsent(c['table_name'] as String, () => <String>{})
          .add(c['entity_id'] as String);
    }

    for (final table in syncTables) {
      final rows = cutoff == null
          ? await db.query(table)
          : await db.query(
              table,
              where: 'updated_at > ?',
              whereArgs: [cutoff],
            );
      final skip = <String>{
        ...?excludeIds[table],
        ...?conflicted[table],
      };
      tables[table] = rows
          .where((r) => !skip.contains(r['id']))
          .map((r) => _prepareRowForExport(table, Map<String, dynamic>.from(r), isDesktop))
          .toList();
    }

    return SyncPayload(
      deviceId: SettingsStore.instance.deviceId,
      timestamp: DateTime.now(),
      since: since,
      tables: tables,
    );
  }

  Map<String, dynamic> _prepareRowForExport(
    String table,
    Map<String, dynamic> row,
    bool isDesktop,
  ) {
    if (table == 'documents') {
      // Absolute paths mean nothing on the other device; bytes travel via
      // /file keyed by sha256.
      row.remove('file_path');
      // Only desktop owns `printed`. Mobile never sends it.
      if (!isDesktop) row.remove('printed');
    }
    if (table == 'children') {
      // At the moment a child leaves this device it is, by definition,
      // being synced.
      row['synced'] = 1;
    }
    return row;
  }

  // ---------------------------------------------------------------------
  // Import / merge
  // ---------------------------------------------------------------------

  Future<ImportResult> importChanges(SyncPayload payload) async {
    final db = await AppDatabase.instance.database;
    final isDesktop = SettingsStore.instance.isDesktop;

    // The baseline "last time both sides agreed". Desktop learns it from
    // the phone's request; the phone knows it itself.
    final base = isDesktop ? payload.since : SettingsStore.instance.lastSyncTime;

    var conflictCount = 0;
    var skipped = 0;
    final applied = <String, Set<String>>{};

    await db.transaction((txn) async {
      for (final table in syncTables) {
        final rows = payload.tables[table];
        if (rows == null) continue;
        final columns = await _columnsOf(txn, table);

        for (final rawRow in rows) {
          final row = Map<String, dynamic>.from(rawRow)
            ..removeWhere((key, _) => !columns.contains(key));
          final id = row['id'] as String?;
          if (id == null) continue;

          final existingRows = await txn.query(
            table,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          final existing = existingRows.isEmpty ? null : existingRows.first;

          if (table == 'documents') {
            row.remove('file_path');
            _applyPrintedRule(row, existing, isDesktop);
          }

          if (existing != null) {
            if (_sameContent(existing, row)) {
              // Both sides already agree. If a human was being asked about
              // this payment, the question has answered itself.
              if (table == 'payments') await _clearConflict(txn, table, id);
              continue;
            }

            if (table == 'payments' && _changedSince(existing, base)) {
              await _recordConflict(txn, table, id, existing, row);
              conflictCount++;
              continue;
            }

            if (!_remoteIsNewer(existing, row)) continue;
          }

          try {
            if (existing == null) {
              await txn.insert(table, row);
            } else {
              await txn.update(table, row, where: 'id = ?', whereArgs: [id]);
            }
            applied.putIfAbsent(table, () => <String>{}).add(id);
          } catch (e) {
            // A row that can't be stored (e.g. its parent child isn't here
            // yet) must not sink the whole batch; the next pass retries it.
            skipped++;
            debugPrint('Sync: skipped $table/$id: $e');
          }
        }
      }
    });

    // Link any document rows we just wrote to bytes we already hold, and
    // list the hashes whose bytes we still need.
    final missingHashes = <String>{};
    for (final id in applied['documents'] ?? const <String>{}) {
      final doc = await db.query('documents', where: 'id = ?', whereArgs: [id]);
      if (doc.isEmpty) continue;
      final hash = doc.first['sha256'] as String?;
      if (!DocumentStorage.isValidHash(hash)) continue;
      final path = await DocumentStorage.localPathForHash(hash!);
      if (path != null) {
        await db.update(
          'documents',
          {'file_path': path},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        missingHashes.add(hash);
      }
    }

    await _refreshStores();

    return ImportResult(
      conflictCount: conflictCount,
      missingHashes: missingHashes.toList(),
      applied: applied,
      skipped: skipped,
    );
  }

  /// Desktop decides `printed`; mobile can't. A registration form that
  /// first arrives from the phone is queued for printing, any other
  /// document type isn't. Desktop ignores `printed` on later updates. On
  /// mobile the value desktop sent is simply adopted (and defaults to
  /// "printed" if absent).
  void _applyPrintedRule(
    Map<String, dynamic> row,
    Map<String, Object?>? existing,
    bool isDesktop,
  ) {
    if (isDesktop) {
      if (existing == null) {
        row['printed'] = row['type'] == 'registration' ? 0 : 1;
      } else {
        row.remove('printed');
      }
    } else if (!row.containsKey('printed') && existing == null) {
      row['printed'] = 1;
    }
  }

  bool _sameContent(Map<String, Object?> local, Map<String, dynamic> remote) {
    for (final entry in remote.entries) {
      if (entry.key == 'updated_at') continue;
      final a = local[entry.key];
      final b = entry.value;
      if (a == b) continue;
      if (a is num && b is num && (a - b).abs() < 1e-9) continue;
      return false;
    }
    return true;
  }

  bool _changedSince(Map<String, Object?> local, DateTime? base) {
    if (base == null) return true;
    final at = DateTime.tryParse(local['updated_at'] as String? ?? '');
    if (at == null) return true;
    return at.isAfter(base);
  }

  bool _remoteIsNewer(Map<String, Object?> local, Map<String, dynamic> remote) {
    final remoteAt = DateTime.tryParse(remote['updated_at'] as String? ?? '');
    if (remoteAt == null) return false;
    final localAt = DateTime.tryParse(local['updated_at'] as String? ?? '');
    if (localAt == null) return true;
    return remoteAt.isAfter(localAt);
  }

  Future<Set<String>> _columnsOf(DatabaseExecutor db, String table) async {
    final cached = _columnCache[table];
    if (cached != null) return cached;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final names = {for (final c in info) c['name'] as String};
    _columnCache[table] = names;
    return names;
  }

  Future<void> _recordConflict(
    DatabaseExecutor txn,
    String table,
    String entityId,
    Map<String, Object?> local,
    Map<String, dynamic> remote,
  ) async {
    final existing = await txn.query(
      'sync_conflicts',
      where: 'table_name = ? AND entity_id = ?',
      whereArgs: [table, entityId],
      limit: 1,
    );
    final conflict = SyncConflict(
      id: existing.isEmpty ? const Uuid().v4() : existing.first['id'] as String,
      tableName: table,
      entityId: entityId,
      localData: Map<String, dynamic>.from(local),
      remoteData: Map<String, dynamic>.from(remote),
      createdAt: existing.isEmpty
          ? DateTime.now()
          : DateTime.parse(existing.first['created_at'] as String),
    );
    if (existing.isEmpty) {
      await txn.insert('sync_conflicts', conflict.toMap());
    } else {
      // Same payment flagged again: refresh what we're comparing instead of
      // stacking up duplicate banners.
      await txn.update(
        'sync_conflicts',
        conflict.toMap(),
        where: 'id = ?',
        whereArgs: [conflict.id],
      );
    }
  }

  Future<void> _clearConflict(
    DatabaseExecutor txn,
    String table,
    String entityId,
  ) async {
    await txn.delete(
      'sync_conflicts',
      where: 'table_name = ? AND entity_id = ?',
      whereArgs: [table, entityId],
    );
  }

  /// Applies the person's choice. There is no auto-resolution and no
  /// timeout — this is only ever called from the compare screen.
  ///
  /// Either way the surviving row is restamped with the current time, so
  /// on the next sync it counts as the newest version and the other side
  /// takes it.
  Future<void> resolveConflict(
    SyncConflict conflict, {
    required bool keepLocal,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      if (keepLocal) {
        // Use the live row, not the snapshot — it may have been edited
        // since the conflict was recorded.
        await txn.update(
          conflict.tableName,
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [conflict.entityId],
        );
      } else {
        final chosen = Map<String, dynamic>.from(conflict.remoteData)
          ..['updated_at'] = now;
        final present = await txn.query(
          conflict.tableName,
          where: 'id = ?',
          whereArgs: [conflict.entityId],
          limit: 1,
        );
        if (present.isEmpty) {
          await txn.insert(conflict.tableName, chosen);
        } else {
          await txn.update(
            conflict.tableName,
            chosen,
            where: 'id = ?',
            whereArgs: [conflict.entityId],
          );
        }
      }
      await txn.delete(
        'sync_conflicts',
        where: 'id = ?',
        whereArgs: [conflict.id],
      );
    });

    await _refreshStores();
  }

  Future<void> _refreshStores() async {
    await ChildrenStore.instance.refresh();
    await ExpensesStore.instance.refresh();
    await FeeTypesStore.instance.refresh();
    await loadConflicts();
  }

  // ---------------------------------------------------------------------
  // Printing (desktop-owned)
  // ---------------------------------------------------------------------

  /// Sets `printed: true` on a document. Restamped so the phone's status
  /// chip flips to "Printed" on its next sync.
  Future<void> markDocumentPrinted(String documentId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'documents',
      {'printed': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
    await ChildrenStore.instance.refresh();
  }

  // ---------------------------------------------------------------------
  // Run state
  // ---------------------------------------------------------------------

  void setRunStatus(SyncRunStatus status, {String? error}) {
    _runStatus = status;
    _lastError = error;
    notifyListeners();
  }

  Future<void> recordSuccessfulSync(DateTime startedAt) async {
    await SettingsStore.instance.setLastSyncTime(startedAt);
    setRunStatus(SyncRunStatus.success);
  }

  /// Flags pushed children as synced. Deliberately leaves `updated_at`
  /// alone: bookkeeping must not look like a new edit.
  Future<void> markChildrenSynced(Iterable<String> childIds) async {
    if (childIds.isEmpty) return;
    final db = await AppDatabase.instance.database;
    for (final id in childIds) {
      await db.update(
        'children',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await ChildrenStore.instance.refresh();
  }

  // ---------------------------------------------------------------------
  // Files
  // ---------------------------------------------------------------------

  /// Hashes of documents whose bytes this device doesn't have yet.
  Future<List<String>> hashesNeedingDownload() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'documents',
      columns: ['sha256'],
      where: "sha256 IS NOT NULL AND sha256 != ''",
    );
    final missing = <String>{};
    for (final row in rows) {
      final hash = row['sha256'] as String?;
      if (!DocumentStorage.isValidHash(hash)) continue;
      if (!await DocumentStorage.hasBytesForHash(hash!)) missing.add(hash);
    }
    return missing.toList();
  }

  /// Where this device keeps the bytes for [hash], if it has them. Looks
  /// for the content-addressed file first, then falls back to a path
  /// recorded on a document row (files saved before storage became
  /// content-addressed), verifying the bytes really match.
  Future<String?> pathForHash(String hash) async {
    if (!DocumentStorage.isValidHash(hash)) return null;
    final direct = await DocumentStorage.localPathForHash(hash);
    if (direct != null) return direct;

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'documents',
      columns: ['file_path'],
      where: 'sha256 = ? AND file_path IS NOT NULL',
      whereArgs: [hash],
    );
    for (final row in rows) {
      final path = row['file_path'] as String?;
      if (path == null || path.isEmpty) continue;
      if (await DocumentStorage.verify(path: path, expectedSha256: hash)) {
        return path;
      }
    }
    return null;
  }

  /// Hashes of every document whose bytes this device holds. Sent with a
  /// push so the receiver can ask for whatever it's missing.
  Future<List<String>> localFileHashes() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'documents',
      columns: ['sha256'],
      where: "sha256 IS NOT NULL AND sha256 != ''",
    );
    final hashes = <String>{};
    for (final row in rows) {
      final hash = row['sha256'] as String?;
      if (!DocumentStorage.isValidHash(hash)) continue;
      if (await hasBytes(hash!)) hashes.add(hash);
    }
    return hashes.toList();
  }

  /// True if this device has verified bytes for [hash] (either storage
  /// layout). Used to skip a transfer entirely when the hash already
  /// matches.
  Future<bool> hasBytes(String hash) async => await pathForHash(hash) != null;

  Future<void> attachDownloadedFile(String hash, String path) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'documents',
      {'file_path': path},
      where: 'sha256 = ?',
      whereArgs: [hash],
    );
    await ChildrenStore.instance.refresh();
  }
}

class ImportResult {
  final int conflictCount;
  final List<String> missingHashes;

  /// Rows actually written (`table -> ids`). The mobile client uses it to
  /// avoid pushing back what it just pulled.
  final Map<String, Set<String>> applied;
  final int skipped;

  const ImportResult({
    required this.conflictCount,
    required this.missingHashes,
    this.applied = const {},
    this.skipped = 0,
  });

  int get appliedCount =>
      applied.values.fold(0, (sum, ids) => sum + ids.length);
}

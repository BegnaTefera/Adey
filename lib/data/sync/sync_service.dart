import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../children_store.dart';
import '../expenses_store.dart';
import '../fee_types_store.dart';
import 'sync_models.dart';

/// Orchestrates exporting, merging, conflict resolution, and store refresh.
class SyncService extends ChangeNotifier {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  List<SyncConflict> _conflicts = [];
  List<SyncConflict> get conflicts => List.unmodifiable(_conflicts);

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

    const targetTables = [
      'children',
      'guardians',
      'documents',
      'attendance',
      'payments',
      'expenses',
      'fee_types',
    ];

    for (final table in targetTables) {
      final rows = await db.query(table);
      tables[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    }

    return SyncPayload(
      deviceId: kIsWeb ? 'web' : 'adey-device',
      timestamp: DateTime.now(),
      tables: tables,
    );
  }

  Future<int> importChanges(SyncPayload payload) async {
    final db = await AppDatabase.instance.database;
    int conflictCount = 0;

    await db.transaction((txn) async {
      for (final entry in payload.tables.entries) {
        final table = entry.key;
        final rows = entry.value;

        for (final row in rows) {
          final id = row['id'] as String?;
          if (id == null) continue;

          if (table == 'payments') {
            final existing = await txn.query('payments', where: 'id = ?', whereArgs: [id]);
            if (existing.isNotEmpty) {
              final localRow = existing.first;
              // If status or amount changed differently on both sides, record conflict
              if (localRow['status'] != row['status'] || localRow['amount'] != row['amount']) {
                await _recordConflict(txn, table, id, localRow, row);
                conflictCount++;
                continue; // Skip overwriting
              }
            }
          }

          // Insert or replace row
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    // Refresh UI stores
    await ChildrenStore.instance.init();
    await ExpensesStore.instance.init();
    await FeeTypesStore.instance.init();
    await loadConflicts();

    return conflictCount;
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
}

import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../models/child.dart';

/// All SQLite access for [Child] and its nested entities lives here.
/// [ChildrenStore] calls into this and keeps an in-memory cache for
/// the UI to listen to — this class doesn't know about that cache, it
/// just talks to the database.
class ChildrenRepository {
  ChildrenRepository._internal();

  static final ChildrenRepository instance = ChildrenRepository._internal();

  Future<List<Child>> fetchAll() async {
    final db = await AppDatabase.instance.database;
    final childRows = await db.query('children', orderBy: 'first_name');

    final children = <Child>[];
    for (final row in childRows) {
      final id = row['id'] as String;
      children.add(Child.fromMap(
        row,
        guardians: await _fetchGuardians(db, id),
        documents: await _fetchDocuments(db, id),
        attendance: await _fetchAttendance(db, id),
        payments: await _fetchPayments(db, id),
      ));
    }
    return children;
  }

  Future<List<Guardian>> _fetchGuardians(Database db, String childId) async {
    final rows = await db.query('guardians', where: 'child_id = ?', whereArgs: [childId]);
    return rows.map(Guardian.fromMap).toList();
  }

  Future<List<ChildDocument>> _fetchDocuments(Database db, String childId) async {
    final rows = await db.query(
      'documents',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'uploaded_at',
    );
    return rows.map(ChildDocument.fromMap).toList();
  }

  Future<List<AttendanceRecord>> _fetchAttendance(Database db, String childId) async {
    final rows = await db.query(
      'attendance',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'date DESC',
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<List<PaymentRecord>> _fetchPayments(Database db, String childId) async {
    final rows = await db.query(
      'payments',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'due_date DESC',
    );
    return rows.map(PaymentRecord.fromMap).toList();
  }

  Future<Map<String, dynamic>> _childRow(
    DatabaseExecutor db,
    Child child,
  ) async {
    final row = child.toMap();
    final columns = await db.rawQuery('PRAGMA table_info(children)');
    if (columns.any((column) => column['name'] == 'medical_notes')) {
      row['medical_notes'] = child.healthCondition;
    }
    return row;
  }

  /// Inserts a brand-new child and all of its nested rows in one
  /// transaction — either everything is saved, or (on error) nothing
  /// is, so a failed registration can't leave a half-written child.
  Future<void> insert(Child child) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.insert('children', await _childRow(txn, child));
      for (final g in child.guardians) {
        await txn.insert('guardians', g.toMap(child.id));
      }
      for (final d in child.documents) {
        await txn.insert('documents', d.toMap(child.id));
      }
      for (final a in child.attendance) {
        await txn.insert('attendance', a.toMap(child.id));
      }
      for (final p in child.payments) {
        await txn.insert('payments', p.toMap(child.id));
      }
    });
  }

  /// Writes an existing child's row and reconciles all nested rows.
  ///
  /// Nested rows are diffed rather than cleared and rewritten: only rows
  /// whose content actually changed get a fresh `updated_at`, and rows
  /// that are gone from the model are deleted. This matters for sync —
  /// "newest `updated_at` wins" only means something if untouched rows
  /// keep their old timestamps instead of all being restamped with the
  /// time of whatever small edit happened to rewrite the child.
  Future<void> update(Child child) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      final childRow = await _childRow(txn, child);
      final existingChild = await txn.query(
        'children',
        where: 'id = ?',
        whereArgs: [child.id],
      );
      if (existingChild.isEmpty) {
        await txn.insert('children', childRow);
      } else {
        await _writeIfChanged(
          txn,
          'children',
          existingChild.first,
          childRow,
          now,
          localOnlyKeys: const {'synced'},
        );
      }

      await _reconcileNested(
        txn,
        'guardians',
        child.id,
        child.guardians.map((g) => g.toMap(child.id)).toList(),
        now,
      );
      await _reconcileNested(
        txn,
        'documents',
        child.id,
        child.documents.map((d) => d.toMap(child.id)).toList(),
        now,
        localOnlyKeys: const {'file_path'},
      );
      await _reconcileNested(
        txn,
        'attendance',
        child.id,
        child.attendance.map((a) => a.toMap(child.id)).toList(),
        now,
      );
      await _reconcileNested(
        txn,
        'payments',
        child.id,
        child.payments.map((p) => p.toMap(child.id)).toList(),
        now,
      );
    });
  }

  Future<void> _reconcileNested(
    DatabaseExecutor txn,
    String table,
    String childId,
    List<Map<String, dynamic>> rows,
    String now, {
    Set<String> localOnlyKeys = const {},
  }) async {
    final existingRows = await txn.query(
      table,
      where: 'child_id = ?',
      whereArgs: [childId],
    );
    final existingById = {
      for (final row in existingRows) row['id'] as String: row,
    };
    final keepIds = <String>{};

    for (final row in rows) {
      final id = row['id'] as String;
      keepIds.add(id);
      final existing = existingById[id];
      if (existing == null) {
        row['updated_at'] = now;
        await txn.insert(table, row);
      } else {
        await _writeIfChanged(
          txn,
          table,
          existing,
          row,
          now,
          localOnlyKeys: localOnlyKeys,
        );
      }
    }

    for (final id in existingById.keys) {
      if (!keepIds.contains(id)) {
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  /// Updates [table] only if [next] differs from [existing]. A change to
  /// shared content restamps `updated_at`; a change only to
  /// [localOnlyKeys] (device-local bookkeeping such as a file path) is
  /// saved without restamping, so it doesn't look like a new edit to sync.
  Future<void> _writeIfChanged(
    DatabaseExecutor txn,
    String table,
    Map<String, Object?> existing,
    Map<String, dynamic> next,
    String now, {
    Set<String> localOnlyKeys = const {},
  }) async {
    final sharedChanged =
        _differs(existing, next, {'updated_at', ...localOnlyKeys});
    final anyChanged = _differs(existing, next, {'updated_at'});
    if (!anyChanged) return;

    final row = Map<String, dynamic>.from(next);
    row['updated_at'] =
        sharedChanged ? now : (existing['updated_at'] ?? now);
    await txn.update(table, row, where: 'id = ?', whereArgs: [existing['id']]);
  }

  bool _differs(
    Map<String, Object?> existing,
    Map<String, dynamic> next,
    Set<String> ignore,
  ) {
    for (final entry in next.entries) {
      if (ignore.contains(entry.key)) continue;
      final a = existing[entry.key];
      final b = entry.value;
      if (a == b) continue;
      if (a is num && b is num && (a - b).abs() < 1e-9) continue;
      return true;
    }
    return false;
  }

  Future<int> count() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM children');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

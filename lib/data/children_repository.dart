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
      orderBy: 'date DESC',
    );
    return rows.map(PaymentRecord.fromMap).toList();
  }

  /// Inserts a brand-new child and all of its nested rows in one
  /// transaction — either everything is saved, or (on error) nothing
  /// is, so a failed registration can't leave a half-written child.
  Future<void> insert(Child child) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.insert('children', child.toMap());
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

  /// Replaces an existing child's row and all nested rows. Nested
  /// tables are cleared and rewritten rather than diffed — simple and
  /// correct for this app's scale (a few hundred records, not
  /// thousands of attendance rows per child).
  Future<void> update(Child child) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update('children', child.toMap(), where: 'id = ?', whereArgs: [child.id]);

      await txn.delete('guardians', where: 'child_id = ?', whereArgs: [child.id]);
      for (final g in child.guardians) {
        await txn.insert('guardians', g.toMap(child.id));
      }

      await txn.delete('documents', where: 'child_id = ?', whereArgs: [child.id]);
      for (final d in child.documents) {
        await txn.insert('documents', d.toMap(child.id));
      }

      await txn.delete('attendance', where: 'child_id = ?', whereArgs: [child.id]);
      for (final a in child.attendance) {
        await txn.insert('attendance', a.toMap(child.id));
      }

      await txn.delete('payments', where: 'child_id = ?', whereArgs: [child.id]);
      for (final p in child.payments) {
        await txn.insert('payments', p.toMap(child.id));
      }
    });
  }

  Future<int> count() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM children');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

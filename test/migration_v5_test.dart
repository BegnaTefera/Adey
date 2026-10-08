import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adey/data/app_database.dart';
import 'package:adey/data/expenses_store.dart';
import 'package:adey/data/fee_types_store.dart';
import 'package:adey/models/expense.dart';

/// Seeds a v4-era database (no `deleted` column), then lets [AppDatabase]
/// run the real v4 → v5 migration, and finally exercises the store-level
/// tombstones the delete features rely on. The tests share one file and run
/// in declaration order because the database singleton opens only once.
void main() {
  late String dbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbPath = p.join(await getDatabasesPath(), 'daycare.db');
    final existing = File(dbPath);
    if (existing.existsSync()) existing.deleteSync();

    final db = await openDatabase(
      dbPath,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE fee_types (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            recurring INTEGER NOT NULL,
            charge_on_registration INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE fee_rates (
            id TEXT PRIMARY KEY,
            fee_type_id TEXT NOT NULL,
            label TEXT NOT NULL,
            min_months INTEGER NOT NULL,
            max_months INTEGER,
            rate REAL NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (fee_type_id) REFERENCES fee_types (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.insert('fee_types', {
          'id': 'ft-1',
          'name': 'Tuition',
          'recurring': 1,
          'charge_on_registration': 0,
          'updated_at': '2026-01-01T00:00:00.000',
        });
        await db.insert('fee_rates', {
          'id': 'fr-1',
          'fee_type_id': 'ft-1',
          'label': 'All ages',
          'min_months': 0,
          'max_months': null,
          'rate': 1500,
          'updated_at': '2026-01-01T00:00:00.000',
        });
        await db.insert('expenses', {
          'id': 'ex-1',
          'category': 'Supplies',
          'amount': 250,
          'date': '2026-01-05T00:00:00.000',
          'note': 'paper',
          'updated_at': '2026-01-05T00:00:00.000',
        });
      },
    );
    await db.close();
  });

  test('v4 → v5 adds the deleted flag without losing rows', () async {
    final db = await AppDatabase.instance.database;
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 5);

    for (final table in ['fee_types', 'expenses']) {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final columns = info.map((c) => c['name']).toSet();
      expect(columns, contains('deleted'), reason: '$table.deleted');
    }

    final fees = await db.query('fee_types');
    expect(fees.single['name'], 'Tuition');
    expect(fees.single['deleted'], 0);

    final rows = await db.query('expenses');
    expect(rows.single['category'], 'Supplies');
  });

  test('fee type delete tombstones the row and hides it from reads',
      () async {
    await FeeTypesStore.instance.init();
    expect(FeeTypesStore.instance.feeTypes.single.name, 'Tuition');

    await FeeTypesStore.instance.delete(FeeTypesStore.instance.feeTypes.single);
    expect(FeeTypesStore.instance.feeTypes, isEmpty);
    expect(FeeTypesStore.instance.hasAnyFeeTypes, isFalse);

    final db = await AppDatabase.instance.database;
    final rows = await db.query('fee_types');
    expect(rows.single['deleted'], 1,
        reason: 'row must survive as a tombstone so sync can carry it');
    final rateRows = await db.query('fee_rates');
    expect(rateRows, hasLength(1), reason: 'age rates stay under the parent');
  });

  test('expense update and delete round-trip', () async {
    await ExpensesStore.instance.init();
    final original = ExpensesStore.instance.expenses.single;

    await ExpensesStore.instance.updateExpense(
      ExpenseItem(
        id: original.id,
        category: original.category,
        amount: original.amount,
        date: DateTime(2026, 2, 3),
        note: original.note,
      ),
    );
    final reloaded = ExpensesStore.instance.expenses.single;
    expect(reloaded.date, DateTime(2026, 2, 3));

    await ExpensesStore.instance.deleteExpense(reloaded.id);
    expect(ExpensesStore.instance.expenses, isEmpty);

    final db = await AppDatabase.instance.database;
    final rows = await db.query('expenses');
    expect(rows.single['deleted'], 1);
  });
}

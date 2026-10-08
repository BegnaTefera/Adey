import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adey/data/app_database.dart';
import 'package:adey/data/children_store.dart';
import 'package:adey/data/expenses_store.dart';
import 'package:adey/data/fee_types_store.dart';
import 'package:adey/models/child.dart';
import 'package:adey/models/expense.dart';

/// Seeds a v4-era database (no `deleted` columns), then lets [AppDatabase]
/// run the real v4 → v6 migration, and finally exercises the store-level
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
        await db.execute('''
          CREATE TABLE children (
            id TEXT PRIMARY KEY,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            gender TEXT NOT NULL DEFAULT 'male',
            dob TEXT NOT NULL,
            allergies TEXT NOT NULL,
            health_condition TEXT NOT NULL DEFAULT '',
            dietary_notes TEXT NOT NULL DEFAULT '',
            special_characteristics TEXT NOT NULL DEFAULT '',
            enrollment_status TEXT NOT NULL,
            enrolled_since TEXT NOT NULL,
            billing_day_override INTEGER,
            synced INTEGER NOT NULL,
            additional_pickup_people TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE guardians (
            id TEXT PRIMARY KEY,
            child_id TEXT NOT NULL,
            name TEXT NOT NULL,
            relationship TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            is_primary INTEGER NOT NULL,
            authorized_pickup INTEGER NOT NULL,
            sub_city TEXT NOT NULL DEFAULT '',
            woreda TEXT NOT NULL DEFAULT '',
            house_number TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL,
            FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            child_id TEXT NOT NULL,
            label TEXT NOT NULL,
            type TEXT NOT NULL,
            uploaded_at TEXT NOT NULL,
            status TEXT NOT NULL,
            file_path TEXT,
            sha256 TEXT,
            printed INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance (
            id TEXT PRIMARY KEY,
            child_id TEXT NOT NULL,
            date TEXT NOT NULL,
            check_in TEXT,
            check_out TEXT,
            status TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE payments (
            id TEXT PRIMARY KEY,
            child_id TEXT NOT NULL,
            fee_type_name TEXT NOT NULL,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            status TEXT NOT NULL,
            due_date TEXT NOT NULL,
            paid_at TEXT,
            cycle_label TEXT,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
          )
        ''');
        await db.insert('children', {
          'id': 'child-1',
          'first_name': 'Abebe',
          'last_name': 'Kebede',
          'gender': 'male',
          'dob': '2021-03-01T00:00:00.000',
          'allergies': '',
          'health_condition': '',
          'dietary_notes': '',
          'special_characteristics': '',
          'enrollment_status': 'enrolled',
          'enrolled_since': '2024-01-10T00:00:00.000',
          'billing_day_override': null,
          'synced': 1,
          'additional_pickup_people': '[]',
          'updated_at': '2026-01-01T00:00:00.000',
        });
        await db.insert('guardians', {
          'id': 'g-1',
          'child_id': 'child-1',
          'name': 'Sara Kebede',
          'relationship': 'Mother',
          'phone': '0911-11-11',
          'email': '',
          'is_primary': 1,
          'authorized_pickup': 1,
          'sub_city': 'Bole',
          'woreda': '3',
          'house_number': '12',
          'updated_at': '2026-01-01T00:00:00.000',
        });
        await db.insert('documents', {
          'id': 'd-1',
          'child_id': 'child-1',
          'label': 'Birth certificate',
          'type': 'other',
          'uploaded_at': '2026-01-02T00:00:00.000',
          'status': 'onFile',
          'file_path': null,
          'sha256': null,
          'printed': 1,
          'updated_at': '2026-01-02T00:00:00.000',
        });
        await db.insert('payments', {
          'id': 'p-1',
          'child_id': 'child-1',
          'fee_type_name': 'Tuition',
          'description': 'Tuition - Meskerem',
          'amount': 1500,
          'status': 'pending',
          'due_date': '2026-01-10T00:00:00.000',
          'paid_at': null,
          'cycle_label': 'Meskerem 2018',
          'updated_at': '2026-01-01T00:00:00.000',
        });
      },
    );
    await db.close();
  });

  test('v4 → v6 adds the deleted flag without losing rows', () async {
    final db = await AppDatabase.instance.database;
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 6);

    for (final table in [
      'fee_types',
      'expenses',
      'guardians',
      'documents',
      'attendance',
      'payments',
    ]) {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final columns = info.map((c) => c['name']).toSet();
      expect(columns, contains('deleted'), reason: '$table.deleted');
    }

    final fees = await db.query('fee_types');
    expect(fees.single['name'], 'Tuition');
    expect(fees.single['deleted'], 0);

    final rows = await db.query('expenses');
    expect(rows.single['category'], 'Supplies');

    final childRows = await db.query('children');
    expect(childRows.single['first_name'], 'Abebe');
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

  test('nested records edit, add, and soft-delete for a child', () async {
    await ChildrenStore.instance.init();
    final child = ChildrenStore.instance.byId('child-1');
    expect(child, isNotNull);
    expect(child!.guardians.single.name, 'Sara Kebede');
    expect(child.documents.single.label, 'Birth certificate');
    expect(child.payments, hasLength(1));

    final edited = child.copyWith(
      guardians: [
        child.guardians.single.copyWith(phone: '0999-88-77'),
      ],
      documents: const <ChildDocument>[],
      payments: [
        ...child.payments,
        PaymentRecord(
          id: 'p-2',
          feeTypeName: 'Tuition',
          description: 'Tuition - Tikimt',
          amount: 1500,
          status: PaymentStatus.pending,
          dueDate: DateTime(2026, 2, 10),
          cycleLabel: 'Tikimt 2018',
        ),
      ],
    );

    await ChildrenStore.instance.updateChild(edited);

    final reloaded = ChildrenStore.instance.byId('child-1')!;
    expect(reloaded.guardians.single.phone, '0999-88-77');
    expect(reloaded.guardians.single.name, 'Sara Kebede',
        reason: 'unrelated fields survive an edit');
    expect(reloaded.documents, isEmpty);
    expect(reloaded.payments, hasLength(2));

    final db = await AppDatabase.instance.database;
    final tombstoned = await db.query('documents',
        where: 'id = ?', whereArgs: ['d-1']);
    expect(tombstoned.single['deleted'], 1,
        reason: 'a document removed from the model becomes a tombstone');
    final kept = await db.query('guardians', where: 'id = ?', whereArgs: ['g-1']);
    expect(kept.single['deleted'], 0,
        reason: 'an edited guardian stays alive');
    expect(kept.single['phone'], '0999-88-77');
  });
}

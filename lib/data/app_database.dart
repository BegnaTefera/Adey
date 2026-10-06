import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Single SQLite database for the app. Opens (and creates, on first
/// run) `daycare.db` in the platform's standard app database
/// directory.
class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daycare.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // sqflite doesn't enforce foreign keys by default — needed for
        // ON DELETE CASCADE to actually clean up a child's guardians,
        // documents, attendance, and payments when the child is removed.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
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
            FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE fee_types (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            recurring INTEGER NOT NULL,
            charge_on_registration INTEGER NOT NULL DEFAULT 0
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
            FOREIGN KEY (fee_type_id) REFERENCES fee_types (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_conflicts (
            id TEXT PRIMARY KEY,
            table_name TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            local_json TEXT NOT NULL,
            remote_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await _insertDefaultFeeTypes(db);
      },
    );
  }

  Future<void> _insertDefaultFeeTypes(DatabaseExecutor db) async {
    const tuitionId = 'seed-fee-tuition';
    const registrationId = 'seed-fee-registration';
    const latePickupId = 'seed-fee-late-pickup';

    await db.insert('fee_types', {
      'id': tuitionId,
      'name': 'Tuition',
      'recurring': 1,
      'charge_on_registration': 0,
    });
    await db.insert('fee_types', {
      'id': registrationId,
      'name': 'Registration fee',
      'recurring': 0,
      'charge_on_registration': 1,
    });
    await db.insert('fee_types', {
      'id': latePickupId,
      'name': 'Late pickup',
      'recurring': 0,
      'charge_on_registration': 0,
    });

    // Placeholder rates — meant to be edited to the daycare's real
    // pricing via the fee editor once it's built.
    final rates = <Map<String, Object?>>[
      {'id': 'seed-rate-1', 'fee_type_id': tuitionId, 'label': 'Infant (0-11mo)', 'min_months': 0, 'max_months': 11, 'rate': 610},
      {'id': 'seed-rate-2', 'fee_type_id': tuitionId, 'label': 'Toddler (12-35mo)', 'min_months': 12, 'max_months': 35, 'rate': 540},
      {'id': 'seed-rate-3', 'fee_type_id': tuitionId, 'label': 'Preschool (36mo+)', 'min_months': 36, 'max_months': null, 'rate': 460},
      {'id': 'seed-rate-4', 'fee_type_id': registrationId, 'label': 'Flat rate', 'min_months': 0, 'max_months': null, 'rate': 300},
      {'id': 'seed-rate-5', 'fee_type_id': latePickupId, 'label': 'Flat rate', 'min_months': 0, 'max_months': null, 'rate': 255},
    ];
    for (final rate in rates) {
      await db.insert('fee_rates', rate);
    }
  }
}

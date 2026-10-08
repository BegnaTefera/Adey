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
      version: 4,
      onConfigure: (db) async {
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.delete(
            'fee_rates',
            where: 'fee_type_id LIKE ?',
            whereArgs: ['seed-%'],
          );
          await db.delete(
            'fee_types',
            where: 'id LIKE ?',
            whereArgs: ['seed-%'],
          );
        }
        if (oldVersion < 3) {
          final now = DateTime.now().toIso8601String();
          for (final table in [
            'guardians',
            'documents',
            'attendance',
            'payments',
            'expenses',
            'fee_types',
            'fee_rates',
          ]) {
            await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
            await db.update(table, {'updated_at': now});
          }
          await db.execute(
            'ALTER TABLE documents ADD COLUMN printed INTEGER NOT NULL DEFAULT 1',
          );
          await db.rawUpdate(
            "UPDATE documents SET printed = 0 WHERE type = 'registration'",
          );
        }
        if (oldVersion < 4) {
          // Databases that predate sync may lack these tables.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_conflicts (
              id TEXT PRIMARY KEY,
              table_name TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              local_json TEXT NOT NULL,
              remote_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }
}

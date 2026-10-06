import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database for the app. Opens (and creates, on first
/// run) `daycare.db` in the platform's standard app database
/// directory. Real local storage — this is what [ChildrenStore] and
/// [ExpensesStore] read from and write to instead of an in-memory list.
///
/// Primary keys are UUID text strings everywhere (not auto-increment
/// ints), matching the record-identity approach from the sync design:
/// once the local-network sync layer is built, offline-created records
/// on mobile and desktop won't collide because ids are never assigned
/// by either device's own counter.
class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daycare.db');
    return openDatabase(
      path,
      version: 3,
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
            date TEXT NOT NULL,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            status TEXT NOT NULL,
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

        await _createFeeTables(db);
        await _insertDefaultFeeTypes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createFeeTables(db);
          await _insertDefaultFeeTypes(db);
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE children ADD COLUMN gender TEXT NOT NULL DEFAULT 'male'");
          await db.execute("ALTER TABLE children ADD COLUMN health_condition TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE children ADD COLUMN dietary_notes TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE children ADD COLUMN special_characteristics TEXT NOT NULL DEFAULT ''");
          // Best-effort carry-over: the old single "medical_notes" field
          // becomes the starting point for the new health_condition
          // field, since that's the closest match of the three new ones.
          await db.execute(
            "UPDATE children SET health_condition = medical_notes WHERE medical_notes IS NOT NULL AND medical_notes != ''",
          );

          await db.execute("ALTER TABLE guardians ADD COLUMN sub_city TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE guardians ADD COLUMN woreda TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE guardians ADD COLUMN house_number TEXT NOT NULL DEFAULT ''");
        }
      },
    );
  }

  Future<void> _createFeeTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fee_types (
        name TEXT PRIMARY KEY,
        recurring INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fee_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fee_type_name TEXT NOT NULL,
        label TEXT NOT NULL,
        min_months INTEGER NOT NULL,
        max_months INTEGER,
        rate REAL NOT NULL,
        FOREIGN KEY (fee_type_name) REFERENCES fee_types (name)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _insertDefaultFeeTypes(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM fee_types'),
        ) ??
        0;
    if (count != 0) return;

    final defaults = <Map<String, Object?>>[
      {'name': 'Tuition', 'recurring': 1},
      {'name': 'Late pickup', 'recurring': 0},
      {'name': 'Field trip', 'recurring': 0},
    ];
    for (final fee in defaults) {
      await db.insert('fee_types', fee);
    }

    final rates = <Map<String, Object?>>[
      {'fee_type_name': 'Tuition', 'label': 'Infant (0-11mo)', 'min_months': 0, 'max_months': 11, 'rate': 610},
      {'fee_type_name': 'Tuition', 'label': 'Toddler (12-35mo)', 'min_months': 12, 'max_months': 35, 'rate': 540},
      {'fee_type_name': 'Tuition', 'label': 'Preschool (36mo+)', 'min_months': 36, 'max_months': null, 'rate': 460},
      {'fee_type_name': 'Late pickup', 'label': 'Flat rate', 'min_months': 0, 'max_months': null, 'rate': 255},
      {'fee_type_name': 'Field trip', 'label': 'Flat rate', 'min_months': 0, 'max_months': null, 'rate': 120},
    ];
    for (final rate in rates) {
      await db.insert('fee_rates', rate);
    }
  }
}

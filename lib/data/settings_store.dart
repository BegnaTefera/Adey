import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

/// Key-value app settings, backed by the `settings` table. One table is
/// plenty for a handful of preferences — no need for a dedicated table
/// per setting.
class SettingsStore extends ChangeNotifier {
  SettingsStore._internal();

  static final SettingsStore instance = SettingsStore._internal();

  static const _calendarKey = 'use_ethiopian_calendar';

  bool useEthiopianCalendar = true;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [_calendarKey]);
    if (rows.isNotEmpty) {
      useEthiopianCalendar = rows.first['value'] == '1';
    }
    _initialized = true;
  }

  Future<void> setUseEthiopianCalendar(bool value) async {
    useEthiopianCalendar = value;
    final db = await AppDatabase.instance.database;
    await db.insert(
      'settings',
      {'key': _calendarKey, 'value': value ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }
}

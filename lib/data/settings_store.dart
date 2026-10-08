import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

/// Key-value app settings, backed by the `settings` table.
class SettingsStore extends ChangeNotifier {
  SettingsStore._internal();

  static final SettingsStore instance = SettingsStore._internal();

  static const _calendarKey = 'use_ethiopian_calendar';
  static const _syncServerIpKey = 'sync_server_ip';
  static const _syncPairingCodeKey = 'sync_pairing_code';
  static const _lastSyncTimeKey = 'last_sync_time';
  static const _deviceIdKey = 'device_id';
  static const _syncServerEnabledKey = 'sync_server_enabled';
  static const _desktopPairingCodeKey = 'desktop_pairing_code';
  static const _pairedDesktopIdKey = 'paired_desktop_id';

  bool useEthiopianCalendar = true;
  String syncServerIp = '';
  String syncPairingCode = '';
  DateTime? lastSyncTime;
  String deviceId = '';
  bool syncServerEnabled = true;
  String desktopPairingCode = '';

  /// Mobile only: the device id of the desktop this phone was first
  /// successfully paired with. Later pings must come from the same id, so
  /// a different machine on the LAN can't pose as the paired desktop.
  String pairedDesktopId = '';
  bool _initialized = false;

  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> init() async {
    if (_initialized) return;
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings');
    final values = {for (final row in rows) row['key'] as String: row['value'] as String};

    useEthiopianCalendar = values[_calendarKey] != '0';
    syncServerIp = values[_syncServerIpKey] ?? '';
    syncPairingCode = values[_syncPairingCodeKey] ?? '';
    final lastSyncRaw = values[_lastSyncTimeKey];
    lastSyncTime = (lastSyncRaw == null || lastSyncRaw.isEmpty)
        ? null
        : DateTime.tryParse(lastSyncRaw);
    deviceId = values[_deviceIdKey] ?? '';
    syncServerEnabled = values[_syncServerEnabledKey] != '0';
    desktopPairingCode = values[_desktopPairingCodeKey] ?? '';
    pairedDesktopId = values[_pairedDesktopIdKey] ?? '';

    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _set(_deviceIdKey, deviceId);
    }
    if (isDesktop && desktopPairingCode.isEmpty) {
      desktopPairingCode = _generatePairingCode();
      await _set(_desktopPairingCodeKey, desktopPairingCode);
    }

    _initialized = true;
  }

  Future<void> setUseEthiopianCalendar(bool value) async {
    useEthiopianCalendar = value;
    await _set(_calendarKey, value ? '1' : '0');
    notifyListeners();
  }

  Future<void> setSyncServerIp(String value) async {
    final next = value.trim();
    if (next == syncServerIp) return;
    syncServerIp = next;
    await _set(_syncServerIpKey, syncServerIp);
    // Pointing at a different address means potentially a different
    // desktop; forget which one we trusted.
    await setPairedDesktopId('');
    notifyListeners();
  }

  Future<void> setSyncPairingCode(String value) async {
    final next = value.trim();
    if (next == syncPairingCode) return;
    syncPairingCode = next;
    await _set(_syncPairingCodeKey, syncPairingCode);
    notifyListeners();
  }

  Future<void> setPairedDesktopId(String value) async {
    pairedDesktopId = value;
    await _set(_pairedDesktopIdKey, value);
  }

  Future<void> setLastSyncTime(DateTime? value) async {
    lastSyncTime = value;
    await _set(_lastSyncTimeKey, value?.toIso8601String() ?? '');
    notifyListeners();
  }

  Future<void> setSyncServerEnabled(bool value) async {
    syncServerEnabled = value;
    await _set(_syncServerEnabledKey, value ? '1' : '0');
    notifyListeners();
  }

  /// Desktop only: replaces the pairing code. The phone has to enter the
  /// new one before it can sync again.
  Future<void> regenerateDesktopPairingCode() async {
    desktopPairingCode = _generatePairingCode();
    await _set(_desktopPairingCodeKey, desktopPairingCode);
    notifyListeners();
  }

  Future<void> _set(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _generatePairingCode() {
    final n = Random.secure().nextInt(900000) + 100000;
    return n.toString();
  }
}

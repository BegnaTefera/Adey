import 'dart:async';

import 'package:flutter/widgets.dart';

import '../children_store.dart';
import '../expenses_store.dart';
import '../fee_types_store.dart';
import '../settings_store.dart';
import 'sync_client.dart';
import 'sync_service.dart';

/// Keeps the phone in step with the desktop without anyone tapping Sync.
///
/// The desktop can't call the phone it has no address for it so this
/// side drives both directions:
///  * a local edit schedules a sync about a second later, so pushes are
///    near-instant;
///  * a light poll every few seconds pulls anything the desktop changed.
///
/// Desktop builds never run this: the desktop *is* the server, and the
/// phone calls it. Polling only runs while the app is in the foreground;
/// on resume it syncs immediately to catch up. When the desktop can't be
/// reached the attempts back off instead of hammering the network.
class AutoSync with WidgetsBindingObserver {
  AutoSync._();

  static final AutoSync instance = AutoSync._();

  static const _changeDelay = Duration(milliseconds: 1200);
  static const _quietAfterRun = Duration(seconds: 1);
  static const _pollFast = Duration(seconds: 5);
  static const _pollSlow = Duration(seconds: 60);

  bool _started = false;
  bool _paused = false;
  bool _running = false;
  int _failures = 0;
  Timer? _debounce;
  Timer? _poll;
  DateTime? _quietUntil;

  bool get isRunning => _running;

  void start() {
    if (_started) return;
    if (SettingsStore.instance.isDesktop) return;
    _started = true;

    ChildrenStore.instance.addListener(_onStoreChanged);
    ExpensesStore.instance.addListener(_onStoreChanged);
    FeeTypesStore.instance.addListener(_onStoreChanged);
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextPoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Whatever happened on the desktop while we were away: catch up now,
      // then let the normal cadence take over.
      _paused = false;
      _scheduleNextPoll(delay: Duration.zero);
    } else {
      _paused = true;
      _poll?.cancel();
      _debounce?.cancel();
    }
  }

  /// Fires when a store changed on *this* device. Changes written by a sync
  /// itself are ignored so an import can't bounce back into another run.
  void _onStoreChanged() {
    if (!_started || _running) return;
    // A sync (manual or automatic) is in progress: these notifications are
    // its own imports arriving, not fresh edits.
    if (SyncService.instance.runStatus == SyncRunStatus.syncing) return;
    final quiet = _quietUntil;
    if (quiet != null && DateTime.now().isBefore(quiet)) return;

    _debounce?.cancel();
    _debounce = Timer(_changeDelay, _run);
  }

  void _scheduleNextPoll({Duration? delay}) {
    _poll?.cancel();
    // A run that was already in flight when the app was backgrounded
    // finishes, then lands here it must not re-arm while paused.
    if (!_started || _paused) return;
    _poll = Timer(delay ?? _nextPollDelay, () async {
      await _run();
      _scheduleNextPoll();
    });
  }

  /// Connected: keep a fast cadence. Unreachable: back off so a closed
  /// desktop doesn't drain the battery with constant timeouts.
  Duration get _nextPollDelay {
    final failures = _failures;
    if (failures == 0) return _pollFast;
    if (failures <= 2) return const Duration(seconds: 10);
    if (failures <= 5) return const Duration(seconds: 20);
    return _pollSlow;
  }

  Future<void> _run() async {
    if (_running || !_started) return;

    final settings = SettingsStore.instance;
    final ip = settings.syncServerIp.trim();
    final code = settings.syncPairingCode.trim();
    if (ip.isEmpty || code.isEmpty) return; // not paired yet

    _running = true;
    try {
      // background: true an automatic run must not flip the UI into the
      // "syncing" state, or the indicator flashes every few seconds.
      final result = await SyncClient.instance.syncNow(background: true);
      if (result.ok) {
        _failures = 0;
        // The import just refreshed every store; don't read that as a new
        // local edit and immediately sync again.
        _quietUntil = DateTime.now().add(_quietAfterRun);
      } else {
        _failures++;
      }
    } catch (_) {
      _failures++;
    } finally {
      _running = false;
    }
  }
}

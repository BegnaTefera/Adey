import 'package:flutter/material.dart';
import '../data/settings_store.dart';
import '../data/sync/sync_client.dart';
import '../data/sync/sync_server.dart';
import '../data/sync/sync_service.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';

/// The sync card on the dashboard — a live indicator, nothing more.
///
/// Mobile (a client): a colored dot — green if synced, red if not — plus a
/// "Sync now" button. The detail (last synced time, auto-sync note, the
/// last error) lives in Settings so the dashboard doesn't flicker every
/// time an automatic background sync completes.
///
/// Desktop (the server): "Sync server: On · 2 devices connected today".
/// It has no last-synced time because nothing is synced *to* anything;
/// it's what gets synced to.
class SyncStatusCard extends StatefulWidget {
  const SyncStatusCard({super.key});

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  String? _serverIp;
  bool _manualSyncing = false;

  @override
  void initState() {
    super.initState();
    SyncService.instance.addListener(_onChange);
    SyncServer.instance.addListener(_onChange);
    SettingsStore.instance.addListener(_onChange);
    if (SettingsStore.instance.isDesktop) _loadIp();
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onChange);
    SyncServer.instance.removeListener(_onChange);
    SettingsStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadIp() async {
    final ip = await SyncServer.instance.getLocalIpAddress();
    if (mounted) setState(() => _serverIp = ip);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _syncNow() async {
    final settings = SettingsStore.instance;
    if (settings.syncServerIp.isEmpty || settings.syncPairingCode.isEmpty) {
      _openSettings();
      return;
    }
    // Local flag, not SyncService.runStatus: background auto-syncs never
    // touch the run status, so this only tracks the user's own tap.
    setState(() => _manualSyncing = true);
    final result = await SyncClient.instance.syncNow();
    if (!mounted) return;
    setState(() => _manualSyncing = false);
    showAppFeedback(
      context,
      message: result.message,
      kind: result.ok ? AppFeedbackKind.success : AppFeedbackKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = SettingsStore.instance.isDesktop;
    return Container(
      decoration: cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _openSettings,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: isDesktop ? _desktopRow() : _mobileRow(),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _desktopRow() {
    final server = SyncServer.instance;
    final running = server.isRunning;
    final devices = server.devicesConnectedToday;
    final title = running
        ? 'Sync server: On · $devices ${devices == 1 ? 'device' : 'devices'} connected today'
        : 'Sync server: Off';
    final subtitle = running
        ? (_serverIp == null
            ? 'Listening on port ${server.port}'
            : 'Listening at $_serverIp:${server.port}')
        : (server.lastError ?? 'Turn it on in Settings so the phone can sync');

    return Row(
      children: [
        _dot(running ? AppColors.sync : AppColors.mutedForeground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.bodyMedium),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileRow() {
    final service = SyncService.instance;
    final settings = SettingsStore.instance;
    final configured =
        settings.syncServerIp.isNotEmpty && settings.syncPairingCode.isNotEmpty;
    final failed = service.runStatus == SyncRunStatus.failed;
    final synced = configured && !failed && service.isRecentlySynced;

    final Color dotColor;
    final String label;
    if (!configured) {
      dotColor = AppColors.accent;
      label = 'Not paired';
    } else if (synced) {
      dotColor = AppColors.sync;
      label = 'Synced';
    } else {
      dotColor = AppColors.danger;
      label = 'Not synced';
    }

    return Row(
      children: [
        _dot(dotColor),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppText.bodyMedium)),
        const SizedBox(width: 8),
        _manualSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : OutlinedButton.icon(
                onPressed: _syncNow,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
      ],
    );
  }
}

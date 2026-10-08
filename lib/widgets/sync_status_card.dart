import 'package:flutter/material.dart';
import '../data/formatters.dart';
import '../data/settings_store.dart';
import '../data/sync/sync_client.dart';
import '../data/sync/sync_server.dart';
import '../data/sync/sync_service.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';

/// The sync card on the dashboard, phrased for each side's role.
///
/// Mobile (a client): a colored dot — green synced within the last few
/// minutes, amber longer ago or never, red if the last attempt failed —
/// plus "Last synced …" and an inline "Sync now".
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
    final result = await SyncClient.instance.syncNow();
    if (!mounted) return;
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
    final syncing = service.runStatus == SyncRunStatus.syncing;
    final failed = service.runStatus == SyncRunStatus.failed;
    final last = service.lastSyncTime;

    final Color dotColor;
    if (failed) {
      dotColor = AppColors.danger;
    } else if (service.isRecentlySynced) {
      dotColor = AppColors.sync;
    } else {
      dotColor = AppColors.accent;
    }

    final title = last == null ? 'Not synced yet' : 'Last synced ${formatDateTime(last)}';
    final String subtitle;
    if (syncing) {
      subtitle = 'Syncing…';
    } else if (failed) {
      subtitle = service.lastError ?? 'The last sync attempt failed';
    } else if (!configured) {
      subtitle = 'Add the desktop address and code in Settings';
    } else {
      subtitle = 'Auto-sync on — edits copy in seconds, no button needed';
    }

    return Row(
      children: [
        _dot(dotColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.bodyMedium),
              Text(
                subtitle,
                style: AppText.caption.copyWith(
                  color: failed ? AppColors.danger : AppColors.mutedForeground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        syncing
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

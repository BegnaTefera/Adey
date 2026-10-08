import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/formatters.dart';
import '../data/settings_store.dart';
import '../data/sync/sync_client.dart';
import '../data/sync/sync_server.dart';
import '../data/sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _desktopIpController;
  late final TextEditingController _pairingCodeController;
  String? _serverIp;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final settings = SettingsStore.instance;
    _desktopIpController = TextEditingController(text: settings.syncServerIp);
    _pairingCodeController =
        TextEditingController(text: settings.syncPairingCode);
    SyncServer.instance.addListener(_onChange);
    SyncService.instance.addListener(_onChange);
    if (settings.isDesktop) _loadIp();
  }

  @override
  void dispose() {
    SyncServer.instance.removeListener(_onChange);
    SyncService.instance.removeListener(_onChange);
    _desktopIpController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadIp() async {
    final ip = await SyncServer.instance.getLocalIpAddress();
    if (mounted) setState(() => _serverIp = ip);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = SettingsStore.instance.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Settings', style: AppText.sectionTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: cardDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text('Ethiopian calendar', style: AppText.bodyMedium),
              subtitle: Text(
                'Show dates in the Ethiopian calendar app-wide. Off shows Gregorian.',
                style: AppText.caption,
              ),
              value: SettingsStore.instance.useEthiopianCalendar,
              activeThumbColor: AppColors.primary,
              onChanged: _saveCalendarPreference,
            ),
          ),
          const SizedBox(height: 16),
          if (isDesktop) _desktopServerCard() else _mobilePairingCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Desktop: the server and the details a phone needs to pair with it
  // ---------------------------------------------------------------------

  Widget _desktopServerCard() {
    final server = SyncServer.instance;
    final running = server.isRunning;
    final devices = server.devicesConnectedToday;

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Sync server',
                  style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(running ? 'On' : 'Off', style: AppText.bodyMedium),
            subtitle: Text(
              running
                  ? '$devices ${devices == 1 ? 'device' : 'devices'} connected today'
                  : (server.lastError ?? 'The phone can\'t sync while this is off.'),
              style: AppText.caption.copyWith(
                color: !running && server.lastError != null
                    ? AppColors.danger
                    : AppColors.mutedForeground,
              ),
            ),
            value: running,
            activeThumbColor: AppColors.primary,
            onChanged: _toggleServer,
          ),
          const Divider(height: 24, color: AppColors.border),
          Text('Address to enter on the phone', style: AppText.caption),
          const SizedBox(height: 4),
          SelectableText(
            _serverIp == null
                ? 'Searching…'
                : '$_serverIp:${server.port}',
            style: AppText.monoCaption.copyWith(
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 14),
          Text('Pairing code', style: AppText.caption),
          const SizedBox(height: 4),
          Row(
            children: [
              SelectableText(
                server.pairingCode,
                style: AppText.monoCaption.copyWith(
                  fontSize: 22,
                  letterSpacing: 4,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: server.pairingCode));
                  if (!mounted) return;
                  showAppFeedback(
                    context,
                    message: 'Pairing code copied.',
                    kind: AppFeedbackKind.info,
                  );
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: _regenerateCode,
                child: const Text('New code'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleServer(bool on) async {
    await SettingsStore.instance.setSyncServerEnabled(on);
    if (on) {
      final started = await SyncServer.instance.start();
      if (!started && mounted) {
        showAppFeedback(
          context,
          message: SyncServer.instance.lastError ?? 'Could not start the sync server.',
          kind: AppFeedbackKind.error,
        );
      }
    } else {
      await SyncServer.instance.stop();
    }
    if (mounted) setState(() {});
  }

  Future<void> _regenerateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate a new code?'),
        content: const Text(
          'The phone will stop syncing until you enter the new code on it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SettingsStore.instance.regenerateDesktopPairingCode();
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Mobile: where the desktop is and how to prove we're paired
  // ---------------------------------------------------------------------

  Widget _mobilePairingCard() {
    final service = SyncService.instance;
    final settings = SettingsStore.instance;
    final syncing = _isSyncing || service.runStatus == SyncRunStatus.syncing;
    final last = service.lastSyncTime;

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Sync with desktop',
                  style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'On the desktop, open Settings to see its address and pairing code.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desktopIpController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onEditingComplete: _saveConnection,
            decoration: const InputDecoration(
              labelText: 'Desktop address',
              hintText: 'e.g. 192.168.1.50',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pairingCodeController,
            keyboardType: TextInputType.number,
            onEditingComplete: _saveConnection,
            decoration: const InputDecoration(
              labelText: 'Pairing code',
              hintText: '6 digits',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: syncing ? null : _triggerManualSync,
              icon: syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_alt),
              label: Text(syncing ? 'Syncing…' : 'Sync now'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            last == null
                ? 'Not synced yet'
                : 'Last synced ${formatDateTime(last)}',
            style: AppText.caption,
          ),
          if (settings.pairedDesktopId.isNotEmpty)
            Text('Paired with a desktop', style: AppText.caption),
          if (service.runStatus == SyncRunStatus.failed &&
              service.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              service.lastError!,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveConnection() async {
    await SettingsStore.instance.setSyncServerIp(_desktopIpController.text);
    await SettingsStore.instance.setSyncPairingCode(_pairingCodeController.text);
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _triggerManualSync() async {
    await _saveConnection();
    if (!mounted) return;
    setState(() => _isSyncing = true);

    final result = await SyncClient.instance.syncNow();

    if (!mounted) return;
    setState(() => _isSyncing = false);
    showAppFeedback(
      context,
      message: result.message,
      kind: result.ok ? AppFeedbackKind.success : AppFeedbackKind.error,
    );
  }

  Future<void> _saveCalendarPreference(bool value) async {
    try {
      await SettingsStore.instance.setUseEthiopianCalendar(value);
      if (!mounted) return;
      setState(() {});
      showAppFeedback(
        context,
        message: 'Calendar preference saved.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save this preference. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () {
          _saveCalendarPreference(value);
        },
      );
    }
  }
}

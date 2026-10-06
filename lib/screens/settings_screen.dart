import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/settings_store.dart';
import '../data/sync/sync_client.dart';
import '../data/sync/sync_server.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _desktopIpController = TextEditingController();
  final _pairingCodeController = TextEditingController(text: '123456');
  String? _serverIp;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final ip = await SyncServer.instance.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _serverIp = ip;
      });
    }
  }

  @override
  void dispose() {
    _desktopIpController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

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

          // Desktop Server Details Card
          if (isDesktop) ...[
            Container(
              decoration: cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dns_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Desktop LAN Sync Server', style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Server Status: ${SyncServer.instance.isRunning ? "Active" : "Stopped"}', style: AppText.caption),
                  const SizedBox(height: 6),
                  Text('Local IP Address: ${_serverIp ?? "Searching..."}', style: AppText.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Pairing Code: ${SyncServer.instance.pairingCode}', style: AppText.monoCaption.copyWith(fontSize: 14, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Mobile / Desktop Sync Connection Card
          Container(
            decoration: cardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Local Network Sync', style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _desktopIpController,
                  decoration: const InputDecoration(
                    labelText: 'Desktop Server IP',
                    hintText: 'e.g. 192.168.1.50',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pairingCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Pairing Code',
                    hintText: '123456',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _triggerManualSync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_alt),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualSync() async {
    final ip = _desktopIpController.text.trim();
    final code = _pairingCodeController.text.trim();

    if (ip.isEmpty) {
      showAppFeedback(
        context,
        message: 'Please enter the Desktop Server IP address.',
        kind: AppFeedbackKind.error,
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final success = await SyncClient.instance.performSync(
        serverIp: ip,
        pairingCode: code,
      );

      if (!mounted) return;
      setState(() => _isSyncing = false);

      if (success) {
        showAppFeedback(
          context,
          message: 'Sync completed successfully!',
          kind: AppFeedbackKind.success,
        );
      } else {
        showAppFeedback(
          context,
          message: 'Could not connect to desktop server. Check IP and pairing code.',
          kind: AppFeedbackKind.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      showAppFeedback(
        context,
        message: 'Sync failed: $e',
        kind: AppFeedbackKind.error,
      );
    }
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

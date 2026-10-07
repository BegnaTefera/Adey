import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/sync/sync_server.dart';
import '../data/sync/sync_service.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

class LiveSyncStatusCard extends StatefulWidget {
  const LiveSyncStatusCard({super.key});

  @override
  State<LiveSyncStatusCard> createState() => _LiveSyncStatusCardState();
}

class _LiveSyncStatusCardState extends State<LiveSyncStatusCard> {
  String? _serverIp;

  @override
  void initState() {
    super.initState();
    _loadIp();
    SyncService.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
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
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final isRunning = SyncServer.instance.isRunning;

    return Container(
      decoration: cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDesktop
                        ? (isRunning ? AppColors.sync : AppColors.mutedForeground)
                        : AppColors.sync,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDesktop && !isRunning)
                            ? Colors.transparent
                            : AppColors.sync.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDesktop ? 'Desktop LAN Sync Server' : 'Live Sync',
                        style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDesktop
                            ? (_serverIp != null ? 'Hosting at $_serverIp:8080' : 'Initializing LAN server...')
                            : 'Connected to local network',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.syncSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDesktop ? (isRunning ? 'Server Active' : 'Stopped') : 'Live Sync',
                    style: AppText.monoCaption.copyWith(
                      color: AppColors.sync,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

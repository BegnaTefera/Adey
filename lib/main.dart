import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/children_store.dart';
import 'data/expenses_store.dart';
import 'data/fee_types_store.dart';
import 'data/settings_store.dart';
import 'data/sync/auto_sync.dart';
import 'data/sync/sync_server.dart';
import 'data/sync/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/app_shell.dart';
import 'screens/desktop_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdeyApp());
}

class AdeyApp extends StatelessWidget {
  const AdeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adey',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppStartup(),
    );
  }
}

/// Opens (and, on first run, seeds) the local SQLite database before
/// showing the real app. The stores load their data from SQLite before
/// the main shell is displayed.
class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _initFuture = _boot();
  }

  Future<void> _boot() async {
    // Settings first: date formatting, the device id and the pairing code
    // all depend on them.
    await SettingsStore.instance.init();
    await Future.wait([
      ChildrenStore.instance.init(),
      ExpensesStore.instance.init(),
      FeeTypesStore.instance.init(),
      SyncService.instance.init(),
    ]);
    // Desktop is the sync server. It listens from app open (if it hasn't
    // been switched off in Settings) — no timers, the phone does the
    // calling. A failure to bind a port is shown in Settings/dashboard
    // rather than blocking the app.
    if (SettingsStore.instance.isDesktop) {
      if (SettingsStore.instance.syncServerEnabled) {
        await SyncServer.instance.start();
      }
    } else {
      // The phone drives sync: push shortly after any local edit, and
      // poll for the desktop's changes while the app is open.
      AutoSync.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storage_outlined,
                      size: 36,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not open local storage.',
                      style: AppText.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: AppText.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => setState(_initialize),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
        return isDesktop ? const DesktopShell() : const AppShell();
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'data/children_store.dart';
import 'data/expenses_store.dart';
import 'data/fee_types_store.dart';
import 'data/settings_store.dart';
import 'theme/app_theme.dart';
import 'screens/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaycareApp());
}

class DaycareApp extends StatelessWidget {
  const DaycareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daycare Manager',
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
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = Future.wait([
      ChildrenStore.instance.init(),
      ExpensesStore.instance.init(),
      FeeTypesStore.instance.init(),
      SettingsStore.instance.init(),
    ]);
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
                child: Text(
                  'Could not open local storage: ${snapshot.error}',
                  style: AppText.bodyRegular,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return const AppShell();
      },
    );
  }
}

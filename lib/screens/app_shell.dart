// lib/screens/app_shell.dart
import 'package:flutter/material.dart';
import '../data/sync/sync_client.dart';
import '../theme/app_theme.dart';
import '../widgets/conflict_banner.dart';
import '../widgets/registration_flow.dart';
import 'attendance_screen.dart';
import 'billing_screen.dart';
import 'children_screen.dart';
import 'dashboard_screen.dart';

enum _Screen { dashboard, attendance, billing, children }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Screen _screen = _Screen.dashboard;

  @override
  void initState() {
    super.initState();
    // Automatically sync when the app opens.
    _syncOnAppOpen();
  }

  Future<void> _syncOnAppOpen() async {
    try {
      final result = await SyncClient.instance.syncNow();
      if (!result.ok) {
        debugPrint('Automatic sync failed: ${result.message}');
      }
    } catch (e) {
      debugPrint('Automatic sync error: $e');
    }
  }

  void _selectScreen(_Screen screen) {
    setState(() => _screen = screen);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _screen == _Screen.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _screen = _Screen.dashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ConflictBanner(),
              Expanded(
                child: IndexedStack(
                  index: _screen.index,
                  children: [
                    DashboardScreen(
                      onOpenAttendance: () => _selectScreen(_Screen.attendance),
                      onOpenBilling: () => _selectScreen(_Screen.billing),
                      onRegister: () => startRegistration(
                        context,
                        onOpenBilling: () =>
                            setState(() => _screen = _Screen.billing),
                      ),
                    ),
                    const AttendanceScreen(),
                    const BillingScreen(),
                    ChildrenScreen(
                      onRegister: () => startRegistration(
                        context,
                        onOpenBilling: () => setState(() => _screen = _Screen.billing),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: _screen.index,
            onDestinationSelected: (index) =>
                _selectScreen(_Screen.values[index]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_available_outlined),
                selectedIcon: Icon(Icons.event_available),
                label: 'Attendance',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Billing',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Children',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

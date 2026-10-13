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

  void _onNavigationSelected(int index) {
    if (index == 2) {
      startRegistration(
        context,
        onOpenBilling: () => setState(() => _screen = _Screen.billing),
      );
      return;
    }

    _selectScreen(_Screen.values[index < 2 ? index : index - 1]);
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
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: NavigationBar(
              animationDuration: const Duration(milliseconds: 300),
              selectedIndex: _screen.index < 2 ? _screen.index : _screen.index + 1,
              onDestinationSelected: _onNavigationSelected,
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
                  icon: CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.add,
                      color: AppColors.primaryForeground,
                    ),
                  ),
                  selectedIcon: CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.add,
                      color: AppColors.primaryForeground,
                    ),
                  ),
                  label: 'Register',
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
      ),
    );
  }
}

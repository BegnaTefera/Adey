import 'package:flutter/material.dart';
import '../data/fee_types_store.dart';
import '../data/sync/sync_service.dart';
import '../widgets/app_feedback.dart';
import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'billing_screen.dart';
import 'children_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'register_screen.dart';
import 'settings_screen.dart';

enum _DesktopTab { dashboard, children, attendance, billing, expenses, settings }

class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  _DesktopTab _activeTab = _DesktopTab.dashboard;

  @override
  void initState() {
    super.initState();
    SyncService.instance.addListener(_onSyncChanged);
    SyncService.instance.init();
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openRegister() async {
    if (!FeeTypesStore.instance.hasAnyFeeTypes) {
      showAppFeedback(
        context,
        message:
            'Create at least one fee type on the Billing screen before registering a child.',
        kind: AppFeedbackKind.info,
      );
      return;
    }
    final childId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted || childId == null) return;
    setState(() {
      _activeTab = _DesktopTab.billing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = SyncService.instance.conflicts;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar Nav
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.child_care, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adey', style: AppText.pageTitle.copyWith(fontSize: 20)),
                          Text('Daycare Manager', style: AppText.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openRegister,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Register Child'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.foreground,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _SidebarItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        label: 'Dashboard',
                        active: _activeTab == _DesktopTab.dashboard,
                        onTap: () => setState(() => _activeTab = _DesktopTab.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.people_outline,
                        activeIcon: Icons.people,
                        label: 'Children',
                        active: _activeTab == _DesktopTab.children,
                        onTap: () => setState(() => _activeTab = _DesktopTab.children),
                      ),
                      _SidebarItem(
                        icon: Icons.calendar_today_outlined,
                        activeIcon: Icons.calendar_today,
                        label: 'Attendance',
                        active: _activeTab == _DesktopTab.attendance,
                        onTap: () => setState(() => _activeTab = _DesktopTab.attendance),
                      ),
                      _SidebarItem(
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        label: 'Billing',
                        active: _activeTab == _DesktopTab.billing,
                        onTap: () => setState(() => _activeTab = _DesktopTab.billing),
                      ),
                      _SidebarItem(
                        icon: Icons.payments_outlined,
                        activeIcon: Icons.payments,
                        label: 'Expenses',
                        active: _activeTab == _DesktopTab.expenses,
                        onTap: () => setState(() => _activeTab = _DesktopTab.expenses),
                      ),
                      _SidebarItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        label: 'Settings',
                        active: _activeTab == _DesktopTab.settings,
                        onTap: () => setState(() => _activeTab = _DesktopTab.settings),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main View Area
          Expanded(
            child: Column(
              children: [
                if (conflicts.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: AppColors.dangerSoft,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sync Conflict: ${conflicts.length} payment record(s) need review.',
                            style: AppText.bodyMedium.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showConflictsDialog(context),
                          child: const Text('Review Conflicts'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: switch (_activeTab) {
                    _DesktopTab.dashboard => const DashboardScreen(),
                    _DesktopTab.children => const ChildrenScreen(),
                    _DesktopTab.attendance => const AttendanceScreen(),
                    _DesktopTab.billing => const BillingScreen(),
                    _DesktopTab.expenses => const ExpensesScreen(),
                    _DesktopTab.settings => const SettingsScreen(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConflictsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final conflicts = SyncService.instance.conflicts;
        return AlertDialog(
          title: const Text('Resolve Sync Conflicts'),
          content: SizedBox(
            width: 500,
            height: 350,
            child: ListView.builder(
              itemCount: conflicts.length,
              itemBuilder: (_, i) {
                final c = conflicts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conflict in ${c.tableName} (ID: ${c.entityId})', style: AppText.bodyMedium),
                        const SizedBox(height: 6),
                        Text('Local: ${c.localData}', style: AppText.caption),
                        Text('Remote: ${c.remoteData}', style: AppText.caption),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await SyncService.instance.resolveConflict(c, keepLocal: true);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Keep Local'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await SyncService.instance.resolveConflict(c, keepLocal: false);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Accept Remote'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AppColors.muted : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: 20,
                  color: active ? AppColors.foreground : AppColors.mutedForeground,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: AppText.bodyMedium.copyWith(
                    color: active ? AppColors.foreground : AppColors.mutedForeground,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
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

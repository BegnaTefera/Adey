import 'package:flutter/material.dart';
import '../data/fee_types_store.dart';
import '../data/sync/sync_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/conflict_banner.dart';
import 'dashboard_screen.dart';
import 'children_screen.dart';
import 'register_screen.dart';
import 'billing_screen.dart';

enum _Screen { dashboard, children, billing }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Screen _screen = _Screen.dashboard;
  String? _registeredChildId;

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
      _registeredChildId = childId;
      _screen = _Screen.billing;
    });
  }

  void _selectScreen(_Screen screen) {
    setState(() {
      _screen = screen;
      if (screen != _Screen.billing) _registeredChildId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ConflictBanner(),
            Expanded(
              child: switch (_screen) {
                _Screen.dashboard => const DashboardScreen(),
                _Screen.children => const ChildrenScreen(),
                _Screen.billing => BillingScreen(
                    key: ValueKey(_registeredChildId),
                    registeredChildId: _registeredChildId,
                  ),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.foreground.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavButton(
                  icon: Icons.home_outlined,
                  label: 'Dashboard',
                  active: _screen == _Screen.dashboard,
                  onTap: () => _selectScreen(_Screen.dashboard),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openRegister,
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Register a child',
                            child: Ink(
                              width: 47,
                              height: 47,
                              decoration: const BoxDecoration(
                                color: AppColors.foreground,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1A1A1916),
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Register',
                            style: AppText.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _NavButton(
                  icon: Icons.people_outline,
                  label: 'Children',
                  active: _screen == _Screen.children,
                  onTap: () => _selectScreen(_Screen.children),
                ),
                _NavButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'Billing',
                  active: _screen == _Screen.billing,
                  onTap: () => _selectScreen(_Screen.billing),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.foreground : AppColors.mutedForeground;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? AppColors.muted : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}


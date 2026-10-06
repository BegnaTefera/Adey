import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'children_screen.dart';
import 'register_screen.dart';

enum _Screen { dashboard, children }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Screen _screen = _Screen.dashboard;

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: switch (_screen) {
          _Screen.dashboard => const DashboardScreen(),
          _Screen.children => const ChildrenScreen(),
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 82,
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
                  onTap: () => setState(() => _screen = _Screen.dashboard),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Register a child',
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _openRegister,
                            customBorder: const CircleBorder(),
                            child: Ink(
                              width: 42,
                              height: 42,
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
                              child: const Icon(Icons.add, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Register',
                          style: AppText.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                _NavButton(
                  icon: Icons.people_outline,
                  label: 'Children',
                  active: _screen == _Screen.children,
                  onTap: () => setState(() => _screen = _Screen.children),
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
                    fontSize: 10,
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


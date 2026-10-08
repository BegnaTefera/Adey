import 'package:flutter/material.dart';
import '../data/children_store.dart';
import '../data/formatters.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';
import '../widgets/sync_status_card.dart';
import 'attendance_screen.dart';
import 'billing_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    ChildrenStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ChildrenStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  List<PaymentRecord> get _overduePayments {
    final result = <PaymentRecord>[];
    for (final child in ChildrenStore.instance.children) {
      result.addAll(child.payments.where((p) => p.isOverdue));
    }
    return result;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final enrolledChildren = ChildrenStore.instance.children
      .where((child) => child.enrollmentStatus == EnrollmentStatus.enrolled)
      .toList();
    final enrolledTotal = enrolledChildren.length;
    final checkedIn = enrolledChildren.where((child) {
      final todayRecord = child.attendance.cast<AttendanceRecord?>().firstWhere(
        (record) => record != null && _isToday(record.date),
        orElse: () => null,
        );
      return todayRecord?.status == AttendanceStatus.present;
    }).length;
    final attendancePct = enrolledTotal == 0
      ? 0
      : (checkedIn / enrolledTotal * 100).round();
    final overdue = _overduePayments;
    final totalOutstanding =
        overdue.fold<double>(0, (sum, p) => sum + p.amount);

    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDate(DateTime.now()).toUpperCase(),
                        style: AppText.monoLabel,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _greeting,
                        style: AppText.pageTitle.copyWith(
                          fontSize: 35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.mutedForeground),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickAction(
                  label: 'Attendance',
                  icon: Icons.calendar_today_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceScreen(),
                    ),
                  ),
                ),
                _QuickAction(
                  label: 'Billing',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BillingScreen(),
                    ),
                  ),
                ),
                _QuickAction(
                  label: 'Expenses',
                  icon: Icons.payments_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExpensesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Today's attendance card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TODAY'S ATTENDANCE", style: AppText.monoLabel),
                      Text('$enrolledTotal enrolled',
                          style: AppText.monoCaption),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$checkedIn', style: AppText.bigNumber),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('/ $enrolledTotal',
                            style: AppText.caption.copyWith(fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: attendancePct / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.muted,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${enrolledTotal - checkedIn} absent today',
                          style: AppText.caption),
                      Text('$attendancePct%',
                          style: AppText.monoCaption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Overdue payments card
            Container(
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('OVERDUE PAYMENTS', style: AppText.monoLabel),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${overdue.length} families',
                            style: AppText.monoCaption.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(overdue.length, (i) {
                    final child = ChildrenStore.instance.children.firstWhere(
                        (c) => c.payments.contains(overdue[i]));
                    final isLast = i == overdue.length - 1;
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(
                                top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary,
                            child: Text(child.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(child.fullName, style: AppText.bodyMedium),
                                Text(
                                  '${DateTime.now().difference(overdue[i].dueDate).inDays}d overdue',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(formatEtb(overdue[i].amount),
                              style: AppText.bodyMedium.copyWith(
                                  color: AppColors.danger,
                                  fontFamily:
                                      AppText.monoCaption.fontFamily)),
                        ],
                      ),
                    );
                  }),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total outstanding', style: AppText.caption),
                        Text(
                          formatEtb(totalOutstanding),
                          style: AppText.bodyMedium.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sync status: client view on mobile, server view on desktop.
            const SyncStatusCard(),
          ],
        ),
      );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: AppText.bodyMedium.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

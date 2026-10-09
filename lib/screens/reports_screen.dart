import 'package:flutter/material.dart';

import '../data/children_store.dart';
import '../data/expenses_store.dart';
import '../data/formatters.dart';
import '../data/report.dart';
import '../data/settings_store.dart';
import '../models/child.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  ReportPeriod _period = ReportPeriod.thisMonth;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    ChildrenStore.instance.addListener(_onStoreChanged);
    ExpensesStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    ChildrenStore.instance.removeListener(_onStoreChanged);
    ExpensesStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final report = buildFinancialReport(
      children: ChildrenStore.instance.children,
      expenses: ExpensesStore.instance.expenses,
      period: _period,
      useEthiopianCalendar: SettingsStore.instance.useEthiopianCalendar,
    );
    final billingCount =
        report.billingByMonth.fold<int>(0, (sum, group) => sum + group.rows.length);
    final expenseCount = report.expensesByMonth
        .fold<int>(0, (sum, group) => sum + group.rows.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Reports', style: AppText.sectionTitle),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(report: report),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final period in ReportPeriod.values)
                          ChoiceChip(
                            label: Text(period.label),
                            selected: _period == period,
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            labelStyle: AppText.bodyMedium.copyWith(
                              color: _period == period
                                  ? Colors.white
                                  : AppColors.foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) =>
                                setState(() => _period = period),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabs,
                labelColor: AppColors.foreground,
                unselectedLabelColor: AppColors.mutedForeground,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: 'Billing ($billingCount)'),
                  Tab(text: 'Expenses ($expenseCount)'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabs,
          children: [
            _BillingTab(report: report),
            _ExpensesTab(report: report),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final FinancialReport report;
  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final net = report.net;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FINANCIAL SUMMARY', style: AppText.monoLabel),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(
                label: 'Collected',
                subtitle: 'received',
                value: formatEtb(report.collected),
                valueColor: AppColors.sync,
              ),
              _StatTile(
                label: 'Outstanding',
                subtitle: 'still due',
                value: formatEtb(report.outstanding),
                valueColor: AppColors.pendingTextDark,
              ),
              _StatTile(
                label: 'Overdue',
                subtitle: 'past due',
                value: formatEtb(report.overdue),
                valueColor: AppColors.danger,
              ),
              _StatTile(
                label: 'Expenses',
                subtitle: 'spent',
                value: formatEtb(report.expenses),
                valueColor: AppColors.primary,
              ),
              _StatTile(
                label: 'Net',
                subtitle: 'collected − expenses',
                value: formatEtb(net),
                valueColor: net == 0
                    ? AppColors.mutedForeground
                    : net < 0
                        ? AppColors.danger
                        : AppColors.sync,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final Color valueColor;

  const _StatTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.monoCaption.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.pageTitle.copyWith(
              fontSize: 20,
              color: valueColor,
              fontFamily: AppText.monoCaption.fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

(Color, Color, String) _paymentStatusDisplay(PaymentRecord payment) {
  return switch (payment.status) {
    PaymentStatus.paid => (AppColors.syncSoft, AppColors.sync, 'Paid'),
    PaymentStatus.cancelled =>
      (AppColors.muted, AppColors.mutedForeground, 'Cancelled'),
    PaymentStatus.pending => payment.isOverdue
        ? (AppColors.dangerSoft, AppColors.danger, 'Overdue')
        : (AppColors.pendingSoft, AppColors.pendingTextDark, 'Pending'),
  };
}

class _BillingTab extends StatelessWidget {
  final FinancialReport report;
  const _BillingTab({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.billingByMonth.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No payments in this period',
        message: 'Try selecting a wider period.',
      );
    }
    return ListView(
      key: const PageStorageKey('reports-billing'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final group in report.billingByMonth) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              group.monthLabel.toUpperCase(),
              style: AppText.monoLabel,
            ),
          ),
          for (final (child, payment) in group.rows)
            _BillingRow(child: child, payment: payment),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _BillingRow extends StatelessWidget {
  final Child child;
  final PaymentRecord payment;
  const _BillingRow({required this.child, required this.payment});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _paymentStatusDisplay(payment);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          ChildAvatar(child: child, radius: 18, fontSize: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.fullName, style: AppText.bodyMedium),
                const SizedBox(height: 2),
                Text(payment.description, style: AppText.caption),
                const SizedBox(height: 2),
                Text(formatDate(payment.dueDate), style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatEtb(payment.amount),
                style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: AppText.monoCaption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  final FinancialReport report;
  const _ExpensesTab({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.expensesByMonth.isEmpty) {
      return const _EmptyState(
        icon: Icons.payments_outlined,
        title: 'No expenses in this period',
        message: 'Try selecting a wider period.',
      );
    }
    return ListView(
      key: const PageStorageKey('reports-expenses'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final group in report.expensesByMonth) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              group.monthLabel.toUpperCase(),
              style: AppText.monoLabel,
            ),
          ),
          for (final expense in group.rows)
            _ExpenseRow(expense: expense),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseItem expense;
  const _ExpenseRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category, style: AppText.bodyMedium),
                const SizedBox(height: 2),
                Text(formatDate(expense.date), style: AppText.caption),
                if (expense.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(expense.note, style: AppText.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatEtb(expense.amount),
            style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(title, style: AppText.bodyMedium),
            const SizedBox(height: 4),
            Text(message, style: AppText.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
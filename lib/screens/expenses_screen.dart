import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/date_range.dart';
import '../data/expenses_store.dart';
import '../data/formatters.dart';
import '../data/search_utils.dart';
import '../data/settings_store.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/empty_illustration.dart';
import '../widgets/metric_card.dart';
import '../widgets/range_filter.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TextEditingController _search = TextEditingController();
  DateRangePreset _rangePreset = DateRangePreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _category;

  @override
  void initState() {
    super.initState();
    ExpensesStore.instance.addListener(_onStoreChanged);
    _search.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ExpensesStore.instance.removeListener(_onStoreChanged);
    _search.removeListener(_onStoreChanged);
    _search.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  DateRange get _range =>
      DateRange(_rangePreset, start: _customStart, end: _customEnd);

  bool get _hasActiveFilters =>
      _search.text.trim().isNotEmpty ||
      _category != null ||
      _rangePreset != DateRangePreset.thisMonth ||
      (_customStart != null && _customEnd != null);

  @override
  Widget build(BuildContext context) {
    final et = SettingsStore.instance.useEthiopianCalendar;
    final range = _range;

    final all = ExpensesStore.instance.expenses;
    final inRange = all
        .where((e) => range.contains(e.date, ethiopian: et))
        .toList();
    final searched = _search.text.trim().isEmpty
        ? inRange
        : inRange.where((e) => _matches(e, _search.text)).toList();

    final categoryCounts = <String, int>{};
    for (final expense in searched) {
      categoryCounts.update(expense.category, (v) => v + 1, ifAbsent: () => 1);
    }
    final categories = categoryCounts.keys.toList()..sort();

    final filtered = _category == null
        ? searched
        : searched.where((e) => e.category == _category).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Expenses', style: AppText.sectionTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add expense', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _summaryStrip(filtered),
          const SizedBox(height: 16),
          _filterCard(categories, categoryCounts, searched.length),
          const SizedBox(height: 20),
          _historyHeader(filtered),
          const SizedBox(height: 12),
          _history(filtered, all.isEmpty, et),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Summary + filters
  // ---------------------------------------------------------------------

  Widget _summaryStrip(List<ExpenseItem> filtered) {
    final total = filtered.fold<double>(0, (sum, e) => sum + e.amount);
    final average = filtered.isEmpty ? 0.0 : total / filtered.length;

    var topCategory = '—';
    if (filtered.isNotEmpty) {
      final byCategory = <String, double>{};
      for (final expense in filtered) {
        byCategory.update(
          expense.category,
          (v) => v + expense.amount,
          ifAbsent: () => expense.amount,
        );
      }
      topCategory = byCategory.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return MetricStrip(
      children: [
        MetricCard(
          label: 'Spent',
          value: formatEtb(total),
          subtitle: _rangePreset.label,
          icon: Icons.payments_outlined,
          accent: AppColors.primary,
        ),
        MetricCard(
          label: 'Entries',
          value: '${filtered.length}',
          subtitle: filtered.length == 1 ? 'expense' : 'expenses',
          icon: Icons.receipt_long_outlined,
          accent: AppColors.accent,
        ),
        MetricCard(
          label: 'Average',
          value: formatEtb(average),
          subtitle: 'per entry',
          icon: Icons.trending_up_outlined,
          accent: AppColors.primary,
        ),
        MetricCard(
          label: 'Top category',
          value: topCategory,
          subtitle: 'highest spend',
          icon: Icons.local_offer_outlined,
          accent: AppColors.accent,
        ),
      ],
    );
  }

  Widget _filterCard(
    List<String> categories,
    Map<String, int> categoryCounts,
    int allCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search expenses',
              hintText: 'Category or note',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _search.clear(),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          RangeFilter(
            preset: _rangePreset,
            customStart: _customStart,
            customEnd: _customEnd,
            onChanged: (preset) => setState(() {
              _rangePreset = preset;
              _category = null;
            }),
            onPickStart: () => _pickCustom(start: true),
            onPickEnd: () => _pickCustom(start: false),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('CATEGORY', style: AppText.monoLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppFilterChip(
                  label: 'All',
                  count: allCount,
                  selected: _category == null,
                  onSelected: () => setState(() => _category = null),
                ),
                for (final category in categories)
                  AppFilterChip(
                    label: category,
                    count: categoryCounts[category] ?? 0,
                    selected: _category == category,
                    onSelected: () => setState(() => _category = category),
                  ),
              ],
            ),
          ],
          if (_hasActiveFilters) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------

  Widget _historyHeader(List<ExpenseItem> filtered) {
    final total = filtered.fold<double>(0, (sum, e) => sum + e.amount);
    return Row(
      children: [
        Text('HISTORY', style: AppText.monoLabel),
        const Spacer(),
        Text(
          '${filtered.length} ${filtered.length == 1 ? 'entry' : 'entries'} · '
          '${formatEtb(total)}',
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _history(List<ExpenseItem> filtered, bool storeEmpty, bool et) {
    if (storeEmpty) {
      return EmptyIllustration(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
        message: 'Log your first expense to start tracking where the money '
            'goes each month.',
        actionLabel: 'Add expense',
        onAction: _addExpense,
      );
    }
    if (filtered.isEmpty) {
      return EmptyIllustration(
        icon: Icons.search_off_outlined,
        title: 'No matching expenses',
        message: 'Try a different search, category, or date range.',
        actionLabel: 'Clear filters',
        onAction: _clearFilters,
        actionIcon: Icons.filter_alt_off_outlined,
      );
    }

    final groups = _groupByMonth(filtered, et);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(group.$1.toUpperCase(), style: AppText.monoLabel),
                ),
                Text(
                  formatEtb(
                    group.$2.fold<double>(0, (sum, e) => sum + e.amount),
                  ),
                  style: AppText.monoCaption.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _ExpenseTable(items: group.$2, onTap: _editExpense),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  List<(String, List<ExpenseItem>)> _groupByMonth(
    List<ExpenseItem> items,
    bool et,
  ) {
    final groups = <String, List<ExpenseItem>>{};
    for (final item in items) {
      groups.putIfAbsent(_monthLabel(item.date, et), () => []).add(item);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date));
    return [for (final entry in entries) (entry.key, entry.value)];
  }

  String _monthLabel(DateTime date, bool ethiopian) {
    if (ethiopian) {
      final et = date.convertToEthiopian();
      return '${amharicMonths[et.month - 1]} ${et.year}';
    }
    return DateFormat('MMM yyyy').format(date);
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  void _clearFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _search.clear();
      _category = null;
      _rangePreset = DateRangePreset.thisMonth;
      _customStart = null;
      _customEnd = null;
    });
  }

  Future<void> _pickCustom({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _customStart : _customEnd) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _customStart = picked;
        if (_customEnd == null || _customEnd!.isBefore(picked)) {
          _customEnd = picked;
        }
      } else {
        _customEnd = picked;
        if (_customStart == null || _customStart!.isAfter(picked)) {
          _customStart = picked;
        }
      }
      _rangePreset = DateRangePreset.custom;
      _category = null;
    });
  }

  bool _matches(ExpenseItem expense, String query) {
    return matchesAllTokens(
      haystacks: [
        normalizeForSearch(expense.category),
        normalizeForSearch(expense.note),
      ],
      normalizedQuery: normalizeForSearch(query),
    );
  }

  // ---------------------------------------------------------------------
  // Create / edit
  // ---------------------------------------------------------------------

  Future<void> _addExpense() => _expenseSheet();

  Future<void> _editExpense(ExpenseItem expense) =>
      _expenseSheet(existing: expense);

  Future<void> _expenseSheet({ExpenseItem? existing}) async {
    final categoryController =
        TextEditingController(text: existing?.category ?? '');
    final amountController = TextEditingController(
      text: existing == null ? '' : _amountText(existing.amount),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    final suggestions = ExpensesStore.instance.expenses
        .map((e) => e.category)
        .toSet()
        .toList()
      ..sort();
    var date = existing?.date ?? DateTime.now();
    var isSaving = false;
    String? categoryError;
    String? amountError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add expense' : 'Edit expense',
                  style: AppText.sectionTitle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Text(formatDate(date), style: AppText.bodyMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked == null || !sheetContext.mounted) {
                                return;
                              }
                              setSheetState(() => date = picked);
                            },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                TextField(
                  controller: categoryController,
                  textCapitalization: TextCapitalization.words,
                  autofocus: existing == null,
                  onChanged: (_) {
                    if (categoryError != null) {
                      setSheetState(() => categoryError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Category',
                    errorText: categoryError,
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in suggestions.take(8))
                        ActionChip(
                          label: Text(suggestion, style: AppText.caption),
                          onPressed: isSaving
                              ? null
                              : () => setSheetState(() {
                                    categoryController.text = suggestion;
                                  }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    if (amountError != null) {
                      setSheetState(() => amountError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount (ETB)',
                    errorText: amountError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountController.text.trim()) ??
                                    0;
                            if (categoryController.text.trim().isEmpty ||
                                amount <= 0) {
                              setSheetState(() {
                                categoryError =
                                    categoryController.text.trim().isEmpty
                                        ? 'Enter a category.'
                                        : null;
                                amountError = amount <= 0
                                    ? 'Enter an amount greater than zero.'
                                    : null;
                              });
                              return;
                            }
                            setSheetState(() {
                              isSaving = true;
                              categoryError = null;
                              amountError = null;
                            });
                            try {
                              final expense = ExpenseItem(
                                id: existing?.id ?? const Uuid().v4(),
                                category: categoryController.text.trim(),
                                amount: amount,
                                date: date,
                                note: noteController.text.trim(),
                              );
                              if (existing == null) {
                                await ExpensesStore.instance.addExpense(expense);
                              } else {
                                await ExpensesStore.instance
                                    .updateExpense(expense);
                              }
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              if (mounted) {
                                showAppFeedback(
                                  context,
                                  message: existing == null
                                      ? 'Expense saved.'
                                      : 'Expense updated.',
                                  kind: AppFeedbackKind.success,
                                );
                              }
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() => isSaving = false);
                              showAppFeedback(
                                sheetContext,
                                message:
                                    'Could not save the expense. Your entry is still here. $error',
                                kind: AppFeedbackKind.error,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(existing == null ? 'Save expense' : 'Save changes'),
                  ),
                ),
                if (existing != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final confirmed =
                                  await _confirmDeleteDialog(existing);
                              if (!sheetContext.mounted || !confirmed) return;
                              Navigator.of(sheetContext).pop();
                              await _deleteExpense(existing);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete expense'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    categoryController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  // ---------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------

  Future<bool> _confirmDeleteDialog(ExpenseItem expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          '${expense.category} — ${formatEtb(expense.amount)} on '
          '${formatDate(expense.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteExpense(ExpenseItem expense) async {    try {
      await ExpensesStore.instance.deleteExpense(expense.id);
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Expense deleted.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not delete this expense. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _deleteExpense(expense),
      );
    }
  }

  String _amountText(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : '$amount';
}

// ---------------------------------------------------------------------
// History table
// ---------------------------------------------------------------------

class _ExpenseTable extends StatelessWidget {
  final List<ExpenseItem> items;
  final ValueChanged<ExpenseItem> onTap;

  const _ExpenseTable({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showDate = constraints.maxWidth >= 420;
        final showNote = constraints.maxWidth >= 620;
        return Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _header(showDate, showNote),
              for (final item in items) _row(item, showDate, showNote),
            ],
          ),
        );
      },
    );
  }

  Widget _header(bool showDate, bool showNote) {
    final style = AppText.monoLabel.copyWith(fontSize: 10);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.muted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showDate) SizedBox(width: 92, child: Text('DATE', style: style)),
          Expanded(flex: 3, child: Text('CATEGORY', style: style)),
          if (showNote)
            Expanded(flex: 4, child: Text('NOTE', style: style)),
          SizedBox(
            width: 110,
            child: Text('AMOUNT', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _row(ExpenseItem item, bool showDate, bool showNote) {
    final label = item.note.isEmpty
        ? 'Edit ${item.category}, ${formatEtb(item.amount)}'
        : 'Edit ${item.category}, ${formatEtb(item.amount)}, ${item.note}';
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () => onTap(item),
        child: Container(
          key: ValueKey(item.id),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (showDate)
                SizedBox(
                  width: 92,
                  child: Text(formatDateShort(item.date),
                      style: AppText.caption),
                ),
              Expanded(
                flex: 3,
                child: Text(
                  item.category,
                  style: AppText.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showNote)
                Expanded(
                  flex: 4,
                  child: Text(
                    item.note.isEmpty ? '—' : item.note,
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(
                width: 110,
                child: Text(
                  formatEtb(item.amount),
                  style: AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

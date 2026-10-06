import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/expenses_store.dart';
import '../data/formatters.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    ExpensesStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ExpensesStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ExpensesStore.instance.expenses;
    final now = DateTime.now();
    final thisMonthTotal = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (sum, item) => sum + item.amount);

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
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('This month', style: AppText.caption),
                Text(
                  formatEtb(thisMonthTotal),
                  style: AppText.pageTitle.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Text('No expenses logged yet', style: AppText.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Add an expense to start tracking this month.',
                      style: AppText.caption, textAlign: TextAlign.center),
                ],
              ),
            ),
          ...expenses.map(
            (expense) => Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                    child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expense.category, style: AppText.bodyMedium),
                        const SizedBox(height: 4),
                        Text(formatDate(expense.date), style: AppText.caption),
                        if (expense.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(expense.note, style: AppText.caption),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    formatEtb(expense.amount),
                    style: AppText.bodyMedium.copyWith(color: AppColors.foreground),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense() async {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    var isSaving = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add expense', style: AppText.sectionTitle),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (ETB)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: AppText.caption.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (categoryController.text.trim().isEmpty || amount <= 0) {
                    setSheetState(() {
                      errorMessage = 'Enter a category and an amount greater than zero.';
                    });
                    return;
                  }
                  setSheetState(() {
                    isSaving = true;
                    errorMessage = null;
                  });
                  try {
                    await ExpensesStore.instance.addExpense(
                      ExpenseItem(
                        id: const Uuid().v4(),
                        category: categoryController.text.trim(),
                        amount: amount,
                        date: DateTime.now(),
                        note: noteController.text.trim(),
                      ),
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    if (mounted) {
                      showAppFeedback(
                        context,
                        message: 'Expense saved.',
                        kind: AppFeedbackKind.success,
                      );
                    }
                  } catch (error) {
                    if (!sheetContext.mounted) return;
                    setSheetState(() => isSaving = false);
                    showAppFeedback(
                      sheetContext,
                      message: 'Could not save the expense. Your entry is still here. $error',
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
                    : const Text('Save expense'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
    categoryController.dispose();
    amountController.dispose();
    noteController.dispose();
  }
}

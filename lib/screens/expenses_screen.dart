import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/expenses_store.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';

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
    final total = expenses.fold<double>(0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Expenses', style: AppText.sectionTitle),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
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
                Text('Monthly total', style: AppText.caption),
                Text(
                  '\$${total.toStringAsFixed(0)}',
                  style: AppText.pageTitle.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No expenses logged yet', style: AppText.caption),
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
                        Text(expense.date, style: AppText.caption),
                        if (expense.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(expense.note, style: AppText.caption),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '\$${expense.amount.toStringAsFixed(0)}',
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

  void _addExpense() {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
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
              decoration: const InputDecoration(labelText: 'Amount'),
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
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (categoryController.text.trim().isEmpty || amount <= 0) return;
                  await ExpensesStore.instance.addExpense(
                    ExpenseItem(
                      id: const Uuid().v4(),
                      category: categoryController.text.trim(),
                      amount: amount,
                      date: DateTime.now().toIso8601String().split('T').first,
                      note: noteController.text.trim(),
                    ),
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

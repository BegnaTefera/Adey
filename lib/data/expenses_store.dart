import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import 'app_database.dart';

/// Reactive cache over SQLite-backed expenses, mirroring
/// [ChildrenStore]'s pattern. A single flat table, so the database
/// calls live directly here rather than in a separate repository file.
class ExpensesStore extends ChangeNotifier {
  ExpensesStore._internal();

  static final ExpensesStore instance = ExpensesStore._internal();

  List<ExpenseItem> _expenses = [];
  bool _initialized = false;

  List<ExpenseItem> get expenses => List.unmodifiable(_expenses);

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    await _refresh();
    _initialized = true;
  }

  /// Forces a re-read from SQLite (used after a sync merge).
  Future<void> refresh() => _refresh();

  Future<void> addExpense(ExpenseItem expense) async {
    final db = await AppDatabase.instance.database;
    await db.insert('expenses', expense.toMap());
    await _refresh();
  }

  Future<void> _refresh() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('expenses', orderBy: 'date DESC');
    _expenses = rows.map(ExpenseItem.fromMap).toList();
    notifyListeners();
  }
}

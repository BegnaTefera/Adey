import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:intl/intl.dart';

import '../models/child.dart';
import '../models/expense.dart';
import 'formatters.dart';

enum ReportPeriod {
  thisMonth,
  lastMonth,
  thisYear,
  allTime;

  String get label => switch (this) {
        ReportPeriod.thisMonth => 'This month',
        ReportPeriod.lastMonth => 'Last month',
        ReportPeriod.thisYear => 'This year',
        ReportPeriod.allTime => 'All time',
      };
}

class MonthlyBilling {
  final String monthLabel;
  final List<(Child, PaymentRecord)> rows;
  const MonthlyBilling({required this.monthLabel, required this.rows});
}

class MonthlyExpenses {
  final String monthLabel;
  final List<ExpenseItem> rows;
  const MonthlyExpenses({required this.monthLabel, required this.rows});
}

class FinancialReport {
  final double collected;
  final double outstanding;
  final double overdue;
  final double expenses;
  final List<MonthlyBilling> billingByMonth;
  final List<MonthlyExpenses> expensesByMonth;

  const FinancialReport({
    required this.collected,
    required this.outstanding,
    required this.overdue,
    required this.expenses,
    required this.billingByMonth,
    required this.expensesByMonth,
  });

  double get net => collected - expenses;
}

/// Aggregates every payment and expense across children into a summary plus
/// month-grouped lists, filtered to [period]. Cancelled payments appear in
/// the lists but never count toward any total (as if never billed).
/// [useEthiopianCalendar] decides whether months are grouped and compared in
/// the Ethiopian calendar (Pagume month 13 included) or the Gregorian one.
FinancialReport buildFinancialReport({
  required List<Child> children,
  required List<ExpenseItem> expenses,
  required ReportPeriod period,
  required bool useEthiopianCalendar,
}) {
  var collected = 0.0;
  var outstanding = 0.0;
  var overdue = 0.0;
  var expenseTotal = 0.0;

  final billingRows = <(Child, PaymentRecord)>[];
  final expenseRows = <ExpenseItem>[];

  for (final child in children) {
    for (final payment in child.payments) {
      if (!_inPeriod(payment.dueDate, period, useEthiopianCalendar)) continue;
      billingRows.add((child, payment));
      if (payment.status == PaymentStatus.cancelled) continue;
      if (payment.status == PaymentStatus.paid) {
        collected += payment.amount;
      } else {
        outstanding += payment.amount;
        if (payment.isOverdue) overdue += payment.amount;
      }
    }
  }

  for (final item in expenses) {
    if (!_inPeriod(item.date, period, useEthiopianCalendar)) continue;
    expenseTotal += item.amount;
    expenseRows.add(item);
  }

  billingRows.sort((a, b) => b.$2.dueDate.compareTo(a.$2.dueDate));
  expenseRows.sort((a, b) => b.date.compareTo(a.date));

  return FinancialReport(
    collected: collected,
    outstanding: outstanding,
    overdue: overdue,
    expenses: expenseTotal,
    billingByMonth: _groupBilling(billingRows, useEthiopianCalendar),
    expensesByMonth: _groupExpenses(expenseRows, useEthiopianCalendar),
  );
}

typedef _MonthKey = (int, int);

List<MonthlyBilling> _groupBilling(
  List<(Child, PaymentRecord)> rows,
  bool ethiopian,
) {
  final groups = <_MonthKey, List<(Child, PaymentRecord)>>{};
  final labels = <_MonthKey, String>{};
  for (final row in rows) {
    final key = _monthKey(row.$2.dueDate, ethiopian);
    groups.putIfAbsent(key, () => []).add(row);
    labels.putIfAbsent(key, () => _monthLabel(row.$2.dueDate, ethiopian));
  }
  return [
    for (final key in _orderedMonths(groups.keys))
      MonthlyBilling(monthLabel: labels[key]!, rows: groups[key]!),
  ];
}

List<MonthlyExpenses> _groupExpenses(List<ExpenseItem> rows, bool ethiopian) {
  final groups = <_MonthKey, List<ExpenseItem>>{};
  final labels = <_MonthKey, String>{};
  for (final row in rows) {
    final key = _monthKey(row.date, ethiopian);
    groups.putIfAbsent(key, () => []).add(row);
    labels.putIfAbsent(key, () => _monthLabel(row.date, ethiopian));
  }
  return [
    for (final key in _orderedMonths(groups.keys))
      MonthlyExpenses(monthLabel: labels[key]!, rows: groups[key]!),
  ];
}

List<_MonthKey> _orderedMonths(Iterable<_MonthKey> keys) {
  final ordered = keys.toList()
    ..sort(
      (a, b) => b.$1 != a.$1
          ? b.$1.compareTo(a.$1)
          : b.$2.compareTo(a.$2),
    );
  return ordered;
}

_MonthKey _monthKey(DateTime date, bool ethiopian) {
  if (ethiopian) {
    final et = date.convertToEthiopian();
    return (et.year, et.month);
  }
  return (date.year, date.month);
}

String _monthLabel(DateTime date, bool ethiopian) {
  if (ethiopian) {
    final et = date.convertToEthiopian();
    return '${amharicMonths[et.month - 1]} ${et.year}';
  }
  return DateFormat('MMM yyyy').format(date);
}

bool _inPeriod(DateTime date, ReportPeriod period, bool ethiopian) {
  if (period == ReportPeriod.allTime) return true;
  final now = DateTime.now();
  if (ethiopian) {
    final d = date.convertToEthiopian();
    final n = now.convertToEthiopian();
    return switch (period) {
      ReportPeriod.thisMonth => d.year == n.year && d.month == n.month,
      ReportPeriod.lastMonth => _previousMonth(n) == (d.year, d.month),
      ReportPeriod.thisYear => d.year == n.year,
      ReportPeriod.allTime => false,
    };
  }
  final previous = DateTime(now.year, now.month - 1, 1);
  return switch (period) {
    ReportPeriod.thisMonth => date.year == now.year && date.month == now.month,
    ReportPeriod.lastMonth =>
      date.year == previous.year && date.month == previous.month,
    ReportPeriod.thisYear => date.year == now.year,
    ReportPeriod.allTime => false,
  };
}

_MonthKey _previousMonth(ETDateTime et) {
  if (et.month == 1) return (et.year - 1, 13);
  return (et.year, et.month - 1);
}
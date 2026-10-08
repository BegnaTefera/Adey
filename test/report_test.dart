import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adey/data/formatters.dart';
import 'package:adey/data/report.dart';
import 'package:adey/models/child.dart';
import 'package:adey/models/expense.dart';

Child _child(String id, List<PaymentRecord> payments) => Child(
      id: id,
      firstName: 'Child',
      lastName: id,
      gender: Gender.male,
      dob: DateTime(2020, 1, 1),
      allergies: const [],
      enrollmentStatus: EnrollmentStatus.enrolled,
      enrolledSince: DateTime(2024, 1, 1),
      guardians: const [],
      documents: const [],
      attendance: const [],
      payments: payments,
    );

PaymentRecord _payment(
  String id, {
  required double amount,
  required PaymentStatus status,
  required DateTime dueDate,
  DateTime? paidAt,
}) =>
    PaymentRecord(
      id: id,
      feeTypeName: 'Tuition',
      description: 'Tuition $id',
      amount: amount,
      status: status,
      dueDate: dueDate,
      paidAt: paidAt,
    );

ExpenseItem _expense(
  String id, {
  required double amount,
  required DateTime date,
}) =>
    ExpenseItem(
      id: id,
      category: 'Supplies',
      amount: amount,
      date: date,
      note: '',
    );

void main() {
  group('buildFinancialReport totals', () {
    test('counts paid and pending, excludes cancelled from sums', () {
      final report = buildFinancialReport(
        children: [
          _child('a', [
            _payment('p1',
                amount: 100,
                status: PaymentStatus.paid,
                dueDate: DateTime(2023, 5, 10),
                paidAt: DateTime(2023, 5, 10)),
            _payment('p2',
                amount: 50,
                status: PaymentStatus.pending,
                dueDate:
                    DateTime.now().subtract(const Duration(days: 40))),
            _payment('p3',
                amount: 30,
                status: PaymentStatus.pending,
                dueDate: DateTime.now().add(const Duration(days: 3))),
            _payment('p4',
                amount: 999,
                status: PaymentStatus.cancelled,
                dueDate: DateTime(2023, 1, 1)),
          ]),
        ],
        expenses: [_expense('e1', amount: 200, date: DateTime(2023, 4, 1))],
        period: ReportPeriod.allTime,
        useEthiopianCalendar: false,
      );

      expect(report.collected, 100);
      expect(report.outstanding, 80);
      expect(report.overdue, 50);
      expect(report.expenses, 200);
      expect(report.net, -100);

      final rows = report.billingByMonth.expand((g) => g.rows).toList();
      expect(rows, hasLength(4),
          reason: 'cancelled rows are still listed');
    });

    test('empty data yields zero totals and no groups', () {
      final report = buildFinancialReport(
        children: const [],
        expenses: const [],
        period: ReportPeriod.allTime,
        useEthiopianCalendar: true,
      );
      expect(report.collected, 0);
      expect(report.outstanding, 0);
      expect(report.overdue, 0);
      expect(report.expenses, 0);
      expect(report.net, 0);
      expect(report.billingByMonth, isEmpty);
      expect(report.expensesByMonth, isEmpty);
    });
  });

  group('Gregorian periods', () {
    test('this month keeps only the current month', () {
      final now = DateTime.now();
      final report = buildFinancialReport(
        children: [
          _child('a', [
            _payment('in',
                amount: 100,
                status: PaymentStatus.paid,
                dueDate: now,
                paidAt: now),
            _payment('out',
                amount: 999,
                status: PaymentStatus.paid,
                dueDate: DateTime(now.year, now.month - 2, 15),
                paidAt: now),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.thisMonth,
        useEthiopianCalendar: false,
      );
      expect(report.collected, 100);
      expect(report.billingByMonth.expand((g) => g.rows), hasLength(1));
    });

    test('last month keeps the month before now, across a year boundary', () {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      final report = buildFinancialReport(
        children: [
          _child('a', [
            _payment('in',
                amount: 100,
                status: PaymentStatus.paid,
                dueDate: lastMonth,
                paidAt: lastMonth),
            _payment('out',
                amount: 999,
                status: PaymentStatus.paid,
                dueDate: now,
                paidAt: now),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.lastMonth,
        useEthiopianCalendar: false,
      );
      expect(report.collected, 100);
    });

    test('this year keeps only the current year', () {
      final now = DateTime.now();
      final report = buildFinancialReport(
        children: [
          _child('a', [
            _payment('in',
                amount: 100,
                status: PaymentStatus.paid,
                dueDate: DateTime(now.year, 1, 15),
                paidAt: now),
            _payment('out',
                amount: 999,
                status: PaymentStatus.paid,
                dueDate: DateTime(now.year - 1, 6, 15),
                paidAt: now),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.thisYear,
        useEthiopianCalendar: false,
      );
      expect(report.collected, 100);
    });
  });

  group('Ethiopian periods and grouping', () {
    test('this month matches the current Ethiopian month', () {
      final now = DateTime.now();
      final inside = buildFinancialReport(
        children: [
          _child('a', [
            _payment('in',
                amount: 100,
                status: PaymentStatus.paid,
                dueDate: now,
                paidAt: now),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.thisMonth,
        useEthiopianCalendar: true,
      );
      expect(inside.collected, 100);

      final outside = buildFinancialReport(
        children: [
          _child('a', [
            _payment('out',
                amount: 999,
                status: PaymentStatus.paid,
                dueDate: DateTime(2000, 1, 5),
                paidAt: DateTime(2000, 1, 5)),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.thisMonth,
        useEthiopianCalendar: true,
      );
      expect(outside.collected, 0);
    });

    test('last month matches the previous Ethiopian month (Pagume aware)', () {
      final nowEt = DateTime.now().convertToEthiopian();
      final previousMonth = nowEt.month == 1 ? 13 : nowEt.month - 1;
      final previousYear = nowEt.month == 1 ? nowEt.year - 1 : nowEt.year;
      final previous = ETDateTime(previousYear, previousMonth, 3)
          .convertToGregorian();

      final report = buildFinancialReport(
        children: [
          _child('a', [
            _payment('in',
                amount: 100,
                status: PaymentStatus.paid,
                dueDate: previous,
                paidAt: previous),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.lastMonth,
        useEthiopianCalendar: true,
      );
      expect(report.collected, 100);
    });

    test('groups by Ethiopian month label, Pagume included, newest first', () {
      final pagume = ETDateTime(2017, 13, 3).convertToGregorian();
      final meskerem = ETDateTime(2017, 1, 5).convertToGregorian();
      final report = buildFinancialReport(
        children: [
          _child('a', [
            _payment('a',
                amount: 10,
                status: PaymentStatus.paid,
                dueDate: pagume,
                paidAt: pagume),
            _payment('b',
                amount: 20,
                status: PaymentStatus.paid,
                dueDate: meskerem,
                paidAt: meskerem),
          ]),
        ],
        expenses: const [],
        period: ReportPeriod.allTime,
        useEthiopianCalendar: true,
      );
      expect(report.billingByMonth, hasLength(2));
      expect(report.billingByMonth.first.monthLabel,
          '${amharicMonths[12]} 2017');
      expect(report.billingByMonth.last.monthLabel,
          '${amharicMonths[0]} 2017');
    });

    test('expenses group by month and sort newest first', () {
      final report = buildFinancialReport(
        children: const [],
        expenses: [
          _expense('e1', amount: 10, date: DateTime(2023, 3, 10)),
          _expense('e2', amount: 20, date: DateTime(2023, 5, 2)),
        ],
        period: ReportPeriod.allTime,
        useEthiopianCalendar: false,
      );
      expect(report.expenses, 30);
      expect(report.expensesByMonth, hasLength(2));
      expect(report.expensesByMonth.first.monthLabel, 'May 2023');
      expect(report.expensesByMonth.last.monthLabel, 'Mar 2023');
    });
  });
}
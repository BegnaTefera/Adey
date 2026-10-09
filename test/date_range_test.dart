import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adey/data/date_range.dart';

void main() {
  group('all time', () {
    test('contains any date regardless of calendar', () {
      const range = DateRange(DateRangePreset.allTime);
      expect(range.isReady, isTrue);
      expect(range.contains(DateTime(1999, 1, 1), ethiopian: false), isTrue);
      expect(range.contains(DateTime(2999, 12, 31), ethiopian: true), isTrue);
    });
  });

  group('custom range', () {
    test('is not ready and filters nothing until both ends are set', () {
      final startOnly = DateRange(DateRangePreset.custom, start: DateTime(2023, 1, 1));
      expect(startOnly.isReady, isFalse);
      expect(startOnly.contains(DateTime(1999, 1, 1), ethiopian: false), isTrue);

      const empty = DateRange(DateRangePreset.custom);
      expect(empty.isReady, isFalse);
      expect(empty.contains(DateTime(1999, 1, 1), ethiopian: false), isTrue);
    });

    test('is inclusive of the start and the whole end day', () {
      final range = DateRange(
        DateRangePreset.custom,
        start: DateTime(2023, 5, 1),
        end: DateTime(2023, 5, 5),
      );
      expect(range.isReady, isTrue);
      expect(range.contains(DateTime(2023, 5, 1, 0, 0), ethiopian: false),
          isTrue);
      expect(range.contains(DateTime(2023, 5, 5, 23, 59), ethiopian: false),
          isTrue);
      expect(range.contains(DateTime(2023, 4, 30, 23, 59), ethiopian: false),
          isFalse);
      expect(range.contains(DateTime(2023, 5, 6, 0, 0), ethiopian: false),
          isFalse);
    });

    test('ignores the calendar setting', () {
      final range = DateRange(
        DateRangePreset.custom,
        start: DateTime(2023, 3, 10),
        end: DateTime(2023, 3, 20),
      );
      expect(range.contains(DateTime(2023, 3, 15), ethiopian: true), isTrue);
      expect(range.contains(DateTime(2023, 3, 15), ethiopian: false), isTrue);
    });
  });

  group('Gregorian presets', () {
    test('this month keeps only the current month', () {
      final now = DateTime.now();
      const range = DateRange(DateRangePreset.thisMonth);
      expect(range.contains(now, ethiopian: false), isTrue);
      expect(
        range.contains(DateTime(now.year, now.month - 2, 15), ethiopian: false),
        isFalse,
      );
    });

    test('last month matches the month before now, across a year boundary', () {
      final now = DateTime.now();
      const range = DateRange(DateRangePreset.lastMonth);
      expect(
        range.contains(DateTime(now.year, now.month - 1, 15), ethiopian: false),
        isTrue,
      );
      expect(range.contains(now, ethiopian: false), isFalse);
    });

    test('this year keeps only the current year', () {
      final now = DateTime.now();
      const range = DateRange(DateRangePreset.thisYear);
      expect(range.contains(DateTime(now.year, 1, 15), ethiopian: false),
          isTrue);
      expect(range.contains(DateTime(now.year - 1, 6, 15), ethiopian: false),
          isFalse);
    });
  });

  group('Ethiopian presets', () {
    test('this month matches the current Ethiopian month', () {
      final now = DateTime.now();
      const range = DateRange(DateRangePreset.thisMonth);
      expect(range.contains(now, ethiopian: true), isTrue);
      expect(range.contains(DateTime(2000, 1, 5), ethiopian: true), isFalse);
    });

    test('last month matches the previous Ethiopian month (Pagume aware)', () {
      final nowEt = DateTime.now().convertToEthiopian();
      final previousMonth = nowEt.month == 1 ? 13 : nowEt.month - 1;
      final previousYear = nowEt.month == 1 ? nowEt.year - 1 : nowEt.year;
      final previous =
          ETDateTime(previousYear, previousMonth, 3).convertToGregorian();

      const range = DateRange(DateRangePreset.lastMonth);
      expect(range.contains(previous, ethiopian: true), isTrue);
      expect(range.contains(DateTime.now(), ethiopian: true), isFalse);
    });

    test('this year keeps only the current Ethiopian year', () {
      final nowEt = DateTime.now().convertToEthiopian();
      const range = DateRange(DateRangePreset.thisYear);
      final inside =
          ETDateTime(nowEt.year, 1, 5).convertToGregorian();
      final outside =
          ETDateTime(nowEt.year - 1, 6, 5).convertToGregorian();
      expect(range.contains(inside, ethiopian: true), isTrue);
      expect(range.contains(outside, ethiopian: true), isFalse);
    });
  });

  group('preset labels', () {
    test('every preset exposes a human label', () {
      for (final preset in DateRangePreset.values) {
        expect(preset.label, isNotEmpty);
      }
    });
  });
}

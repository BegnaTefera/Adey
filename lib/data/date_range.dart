import 'package:ethiopian_datetime/ethiopian_datetime.dart';

/// Preset reporting windows shared by the Expenses and Attendance screens.
/// Mirrors the period logic in [report.dart] so month/year boundaries follow
/// the active calendar setting (Ethiopian by default, Gregorian when the user
/// switches it in Settings).
enum DateRangePreset {
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year'),
  allTime('All time'),
  custom('Custom');

  const DateRangePreset(this.label);

  final String label;
}

typedef _MonthKey = (int, int);

/// A selected reporting window. Presets resolve relative to "now"; [custom]
/// carries explicit inclusive [start]/[end] days.
class DateRange {
  final DateRangePreset preset;
  final DateTime? start;
  final DateTime? end;

  const DateRange(this.preset, {this.start, this.end});

  factory DateRange.preset(DateRangePreset preset) => DateRange(preset);

  bool get isCustom => preset == DateRangePreset.custom;

  /// A custom range only filters once both ends are chosen; until then it
  /// behaves like "all time" so the list never blanks out mid-selection.
  bool get isReady =>
      preset != DateRangePreset.custom || (start != null && end != null);

  bool contains(DateTime date, {required bool ethiopian}) {
    if (preset == DateRangePreset.allTime) return true;
    if (preset == DateRangePreset.custom) {
      final s = start;
      final e = end;
      if (s == null || e == null) return true;
      final from = DateTime(s.year, s.month, s.day);
      final until =
          DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
      return !date.isBefore(from) && date.isBefore(until);
    }

    if (ethiopian) {
      final d = date.convertToEthiopian();
      final n = DateTime.now().convertToEthiopian();
      return switch (preset) {
        DateRangePreset.thisMonth => d.year == n.year && d.month == n.month,
        DateRangePreset.lastMonth => _previousMonth(n) == (d.year, d.month),
        DateRangePreset.thisYear => d.year == n.year,
        _ => true,
      };
    }

    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1, 1);
    return switch (preset) {
      DateRangePreset.thisMonth =>
        date.year == now.year && date.month == now.month,
      DateRangePreset.lastMonth =>
        date.year == previous.year && date.month == previous.month,
      DateRangePreset.thisYear => date.year == now.year,
      _ => true,
    };
  }

  _MonthKey _previousMonth(ETDateTime et) {
    if (et.month == 1) return (et.year - 1, 13);
    return (et.year, et.month - 1);
  }
}

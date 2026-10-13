import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';

import '../data/formatters.dart';
import '../data/settings_store.dart';
import '../theme/app_theme.dart';

/// The single entry point for picking a date anywhere in the app.
///
/// Honors the "use Ethiopian calendar" setting: when it is on the custom
/// Ethiopian [EthiopianDatePickerDialog] is shown, otherwise the stock
/// Gregorian [showDatePicker] is used. Regardless of the calendar shown,
/// the returned [DateTime] is always Gregorian, so callers can keep
/// storing and comparing dates the same way they always have.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Select date',
}) {
  final safeInitial = _clamp(initialDate, firstDate, lastDate);
  if (SettingsStore.instance.useEthiopianCalendar) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => EthiopianDatePickerDialog(
        title: title,
        initialDate: safeInitial.convertToEthiopian(),
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }
  return showDatePicker(
    context: context,
    initialDate: safeInitial,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

DateTime _clamp(DateTime date, DateTime first, DateTime last) {
  if (date.isBefore(first)) return first;
  if (date.isAfter(last)) return last;
  return date;
}

/// Ethiopian (Ge'ez) month grid picker. Returns the selected date as a
/// Gregorian [DateTime] via `Navigator.pop`.
class EthiopianDatePickerDialog extends StatefulWidget {
  final String title;
  final ETDateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const EthiopianDatePickerDialog({
    super.key,
    this.title = 'Select date',
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<EthiopianDatePickerDialog> createState() =>
      _EthiopianDatePickerDialogState();
}

class _EthiopianDatePickerDialogState
    extends State<EthiopianDatePickerDialog> {
  late int _year;
  late int _month;
  late (int, int) _showableMonth;

  ETDateTime get _firstEthiopian => widget.firstDate.convertToEthiopian();

  ETDateTime get _lastEthiopian => widget.lastDate.convertToEthiopian();

  List<int> get _availableYears => [
        for (var year = _firstEthiopian.year;
            year <= _lastEthiopian.year;
            year++)
          year,
      ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _showableMonth = _clampMonth(_year, _month);
    _year = _showableMonth.$1;
    _month = _showableMonth.$2;
  }

  (int, int) _clampMonth(int year, int month) {
    if (_compareMonth(year, month, _firstEthiopian.year, _firstEthiopian.month) < 0) {
      return (_firstEthiopian.year, _firstEthiopian.month);
    }
    if (_compareMonth(year, month, _lastEthiopian.year, _lastEthiopian.month) > 0) {
      return (_lastEthiopian.year, _lastEthiopian.month);
    }
    return (year, month);
  }

  int _compareMonth(int yearA, int monthA, int yearB, int monthB) {
    return (yearA * 13 + monthA).compareTo(yearB * 13 + monthB);
  }

  int get _daysInMonth =>
      _month == 13 ? (_year % 4 == 3 ? 6 : 5) : 30;

  bool _isSelectable(int day) {
    final date = ETDateTime(_year, _month, day).convertToGregorian();
    return !_dateOnly(date).isBefore(_dateOnly(widget.firstDate)) &&
        !_dateOnly(date).isAfter(_dateOnly(widget.lastDate));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSelected(int day) {
    final selected = widget.initialDate.convertToGregorian();
    final date = ETDateTime(_year, _month, day).convertToGregorian();
    return selected.year == date.year &&
        selected.month == date.month &&
        selected.day == date.day;
  }

  void _changeMonth(int amount) {
    var year = _year;
    var month = _month + amount;
    if (month < 1) {
      month = 13;
      year--;
    } else if (month > 13) {
      month = 1;
      year++;
    }
    final clamped = _clampMonth(year, month);
    setState(() {
      _year = clamped.$1;
      _month = clamped.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = ETDateTime(_year, _month, 1).weekday;
    final gridCount = (firstWeekday - 1) + _daysInMonth;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: AppText.sectionTitle),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close calendar',
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _compareMonth(_year, _month,
                                _firstEthiopian.year, _firstEthiopian.month) >
                            0
                        ? () => _changeMonth(-1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  Expanded(
                    child: Text(
                      '${amharicMonths[_month - 1]} $_year',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _compareMonth(_year, _month,
                                _lastEthiopian.year, _lastEthiopian.month) <
                            0
                        ? () => _changeMonth(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              ),
              DropdownButton<int>(
                value: _year,
                underline: const SizedBox.shrink(),
                items: _availableYears
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year', style: AppText.bodyMedium),
                      ),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year == null) return;
                  final clamped = _clampMonth(year, _month);
                  setState(() {
                    _year = clamped.$1;
                    _month = clamped.$2;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children:
                    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map(
                          (day) => Expanded(
                            child: Center(child: Text(day)),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gridCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final day = index - firstWeekday + 2;
                  if (day < 1 || day > _daysInMonth) return const SizedBox();
                  final selectable = _isSelectable(day);
                  final selected = _isSelected(day);
                  return InkWell(
                    onTap: selectable
                        ? () => Navigator.of(context).pop(
                              ETDateTime(_year, _month, day)
                                  .convertToGregorian(),
                            )
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$day',
                        style: AppText.bodyRegular.copyWith(
                          color: !selectable
                              ? AppColors.mutedForeground
                                  .withValues(alpha: 0.4)
                              : selected
                                  ? Colors.white
                                  : AppColors.foreground,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

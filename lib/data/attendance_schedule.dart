/// Shared attendance operating-day rules.
///
/// The daycare day starts at [dayStartHour] (07:00). Before then the register
/// still targets the previous day, so a mark made at 06:30 belongs to
/// yesterday's sheet rather than starting a fresh (empty) one.
///
/// Sundays are days off: any computed day that lands on a Sunday is pulled
/// back to the nearest working day (Saturday). This keeps the default register
/// on the last day the daycare was actually open.
class AttendanceSchedule {
  const AttendanceSchedule._();

  /// Hour of day (24h) at which a new attendance day begins.
  static const int dayStartHour = 7;

  /// Whether [day] is a non-working day (Sunday).
  static bool isDayOff(DateTime day) => day.weekday == DateTime.sunday;

  /// The working day the register should target at [now].
  static DateTime operatingDay([DateTime? now]) {
    final clock = now ?? DateTime.now();
    final date = DateTime(clock.year, clock.month, clock.day);
    var day = clock.hour < dayStartHour
        ? date.subtract(const Duration(days: 1))
        : date;
    while (isDayOff(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }

  /// Whether [day] is the current operating day. Used to decide when to
  /// stamp a check-in time (only for the live sheet, never back-dated).
  static bool isCurrentOperatingDay(DateTime day, [DateTime? now]) {
    final target = operatingDay(now);
    return day.year == target.year &&
        day.month == target.month &&
        day.day == target.day;
  }
}

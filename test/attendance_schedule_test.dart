import 'package:flutter_test/flutter_test.dart';

import 'package:adey/data/attendance_schedule.dart';

// 2023-01-01 is a Sunday, so these cover a full week with fixed weekdays.
final _sun = DateTime(2023, 1, 1);
final _mon = DateTime(2023, 1, 2);
final _tue = DateTime(2023, 1, 3);
final _wed = DateTime(2023, 1, 4);
final _fri = DateTime(2023, 1, 6);
final _sat = DateTime(2023, 1, 7);
final _prevSat = DateTime(2022, 12, 31);

void main() {
  test('day starts at 07:00', () {
    expect(AttendanceSchedule.dayStartHour, 7);
  });

  group('isDayOff', () {
    test('only Sunday is a day off', () {
      expect(AttendanceSchedule.isDayOff(_sun), isTrue);
      for (final day in [_mon, _tue, _wed, _fri, _sat]) {
        expect(AttendanceSchedule.isDayOff(day), isFalse);
      }
    });
  });

  group('operatingDay', () {
    test('before 07:00 targets the previous day', () {
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 4, 6, 59)),
        DateTime(2023, 1, 3),
      );
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 7, 6, 0)),
        _fri,
      );
    });

    test('at or after 07:00 targets the same day', () {
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 2, 7, 0)),
        _mon,
      );
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 4, 23, 0)),
        _wed,
      );
    });

    test('never returns a Sunday', () {
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 1, 10, 0)),
        _prevSat,
      );
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 1, 5, 0)),
        _prevSat,
      );
      // Monday before opening rolls back past Sunday to Saturday.
      expect(
        AttendanceSchedule.operatingDay(DateTime(2023, 1, 2, 6, 30)),
        _prevSat,
      );
    });

    test('defaults to now when not given a clock', () {
      final result = AttendanceSchedule.operatingDay();
      expect(AttendanceSchedule.isDayOff(result), isFalse);
    });
  });

  group('isCurrentOperatingDay', () {
    test('true only for the sheet the register should show', () {
      final morning = DateTime(2023, 1, 2, 8, 0);
      expect(AttendanceSchedule.isCurrentOperatingDay(_mon, morning), isTrue);
      expect(AttendanceSchedule.isCurrentOperatingDay(_sun, morning), isFalse);

      final earlyMonday = DateTime(2023, 1, 2, 6, 0);
      expect(
        AttendanceSchedule.isCurrentOperatingDay(_prevSat, earlyMonday),
        isTrue,
      );
      expect(
        AttendanceSchedule.isCurrentOperatingDay(_mon, earlyMonday),
        isFalse,
      );

      expect(
        AttendanceSchedule.isCurrentOperatingDay(
          _prevSat,
          DateTime(2023, 1, 1, 12, 0),
        ),
        isTrue,
      );
    });
  });
}

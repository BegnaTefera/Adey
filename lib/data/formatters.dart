import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:intl/intl.dart';
import 'settings_store.dart';

/// Amharic month names, single source of truth (was previously
/// duplicated in register_screen.dart and registration_pdf.dart).
const amharicMonths = [
  'መስከረም',
  'ጥቅምት',
  'ኅዳር',
  'ታኅሳስ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜ',
];

/// Formats a date for display, honoring the calendar setting. Ethiopian
/// is the default and main calendar per the app's design; Gregorian is
/// the fallback when the user switches it in Settings.
String formatDate(DateTime date) {
  if (SettingsStore.instance.useEthiopianCalendar) {
    final et = date.convertToEthiopian();
    return '${et.day} ${amharicMonths[et.month - 1]} ${et.year}';
  }
  return DateFormat('MMM d, yyyy').format(date);
}

/// Same as [formatDate] but without the year for compact list rows.
String formatDateShort(DateTime date) {
  if (SettingsStore.instance.useEthiopianCalendar) {
    final et = date.convertToEthiopian();
    return '${et.day} ${amharicMonths[et.month - 1]}';
  }
  return DateFormat('MMM d').format(date);
}

/// Clock time, e.g. "3:42 PM".
String formatTime(DateTime time) => DateFormat('h:mm a').format(time);

/// Date (honoring the calendar setting) plus clock time for "last
/// synced" style timestamps.
String formatDateTime(DateTime dateTime) =>
    '${formatDate(dateTime)}, ${formatTime(dateTime)}';

String formatEtb(double amount) => 'ETB ${amount.toStringAsFixed(0)}';

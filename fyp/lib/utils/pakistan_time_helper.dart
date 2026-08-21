import 'package:intl/intl.dart';

class PakistanTimeHelper {
  static DateTime parseUtc(String dateString, {DateTime? fallback}) {
    return DateTime.tryParse(dateString.trim())?.toLocal() ??
        fallback ??
        DateTime.now();
  }

  static DateTime parseUtcNullable(String? dateString, {DateTime? fallback}) {
    if (dateString == null || dateString.trim().isEmpty) {
      return fallback ?? DateTime.now();
    }

    return parseUtc(dateString, fallback: fallback);
  }

  static DateTime toPakistanTime(DateTime dateTime) {
    return dateTime.toLocal();
  }

  static String formatPakistanTime(DateTime dateTime, String pattern) {
    return DateFormat(pattern).format(dateTime.toLocal());
  }

  static String formatPakistanTimeFromString(
      String dateString, String pattern) {
    return formatPakistanTime(parseUtc(dateString), pattern);
  }

  static bool isSamePakistanDate(DateTime first, DateTime second) {
    final localFirst = first.toLocal();
    final localSecond = second.toLocal();
    return localFirst.year == localSecond.year &&
        localFirst.month == localSecond.month &&
        localFirst.day == localSecond.day;
  }

  static DateTime toUtcFromPakistanFields(DateTime pakistanDateTime) {
    return DateTime.utc(
      pakistanDateTime.year,
      pakistanDateTime.month,
      pakistanDateTime.day,
      pakistanDateTime.hour,
      pakistanDateTime.minute,
      pakistanDateTime.second,
      pakistanDateTime.millisecond,
      pakistanDateTime.microsecond,
    );
  }

  static DateTime nowPakistan() => DateTime.now();
}

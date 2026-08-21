import 'package:intl/intl.dart';

void main() {
  DateTime dtUtc = DateTime.utc(2026, 5, 6, 21, 46);
  print('dtUtc: $dtUtc (isUtc: ${dtUtc.isUtc})');
  print('DateFormat: ${DateFormat('hh:mm a').format(dtUtc)}');

  // Let's create a UTC date that Intl *might* convert to local
  // Actually, Intl uses the local timezone for formatting by default?
  // Let's print dtUtc.toLocal() to see what local time it is on the machine.
  print('dtUtc.toLocal(): ${dtUtc.toLocal()}');
  print('DateFormat(dtUtc.toLocal()): ${DateFormat('hh:mm a').format(dtUtc.toLocal())}');
}

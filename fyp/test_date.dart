import 'package:intl/intl.dart';

void main() {
  DateTime dt = DateTime.utc(2026, 5, 6, 21, 46);
  print(dt);
  print(dt.isUtc);
  print(DateFormat('hh:mm a').format(dt));
  
  DateTime dtLocal = DateTime(2026, 5, 6, 21, 46);
  print(dtLocal);
  print(dtLocal.isUtc);
  print(DateFormat('hh:mm a').format(dtLocal));
}

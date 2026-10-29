import 'package:intl/intl.dart';

final _hm = DateFormat('HH:mm');
final _dmy = DateFormat('dd/MM/yyyy');

String formatTime(DateTime t) => _hm.format(t);
String formatDay(DateTime t) => _dmy.format(t);

const _weekdays = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];

/// "Thứ tư, 29/10/2026" (không phụ thuộc locale của máy).
String formatDayWithWeekday(DateTime t) => '${_weekdays[t.weekday - 1]}, ${formatDay(t)}';

String monthTitle(int year, int month) => 'Tháng $month/$year';

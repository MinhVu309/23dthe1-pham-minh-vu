import 'package:flutter/material.dart';

import '../admin/fraud_alerts_page.dart';
import '../employee/leaves_page.dart';
import '../map/attendance_map_page.dart';
import '../reports/timesheet_page.dart';
import '../shared/home_shell.dart';
import '../shared/today_cards.dart';
import 'qr_display_page.dart';

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) {
    const attendance = 'Chấm công';
    final qr = HomeModule(Icons.qr_code_2_rounded, 'Điểm chấm công', 'Hiển thị mã QR động', group: attendance, builder: (_) => const QrDisplayPage());
    final sheet = HomeModule(Icons.fact_check_outlined, 'Bảng công', 'Chấm công theo ngày, theo tháng', group: attendance, builder: (_) => const TimesheetPage());
    final map = HomeModule(Icons.map_outlined, 'Bản đồ chấm công', 'Vị trí chấm công của nhân viên', group: attendance, builder: (_) => const AttendanceMapPage());
    final fraud = HomeModule(Icons.gpp_maybe_outlined, 'Cảnh báo gian lận', 'Xem và xử lý cảnh báo', group: attendance, builder: (_) => const FraudAlertsPage());
    final leaves = HomeModule(Icons.beach_access_outlined, 'Duyệt nghỉ phép', 'Đơn đang chờ duyệt', group: 'Nghỉ phép', builder: (_) => const LeavesPage());
    return HomeShell(
      tagline: 'Theo dõi đội nhóm và điểm chấm công.',
      modules: [qr, sheet, map, fraud, leaves],
      fab: qr,
      shortcuts: [sheet, leaves],
      summary: (_, token) => StaffTodayCard(refreshToken: token),
    );
  }
}

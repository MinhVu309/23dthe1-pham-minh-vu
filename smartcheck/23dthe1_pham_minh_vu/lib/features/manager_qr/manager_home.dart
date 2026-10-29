import 'package:flutter/material.dart';

import '../admin/fraud_alerts_page.dart';
import '../employee/leaves_page.dart';
import '../map/attendance_map_page.dart';
import '../reports/timesheet_page.dart';
import '../shared/home_shell.dart';
import 'qr_display_page.dart';

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) => HomeShell(
        tagline: 'Theo dõi đội nhóm và điểm chấm công.',
        modules: [
          HomeModule(Icons.qr_code_2_rounded, 'Điểm chấm công', 'Hiển thị mã QR động', builder: (_) => const QrDisplayPage()),
          HomeModule(Icons.fact_check_outlined, 'Bảng công', 'Chấm công theo ngày, theo tháng', builder: (_) => const TimesheetPage()),
          HomeModule(Icons.beach_access_outlined, 'Duyệt nghỉ phép', 'Đơn đang chờ duyệt', builder: (_) => const LeavesPage()),
          HomeModule(Icons.map_outlined, 'Bản đồ chấm công', 'Vị trí chấm công của nhân viên', builder: (_) => const AttendanceMapPage()),
          HomeModule(Icons.gpp_maybe_outlined, 'Cảnh báo gian lận', 'Xem và xử lý cảnh báo', builder: (_) => const FraudAlertsPage()),
        ],
      );
}

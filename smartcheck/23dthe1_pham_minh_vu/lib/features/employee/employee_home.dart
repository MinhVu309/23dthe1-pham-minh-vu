import 'package:flutter/material.dart';

import '../reports/attendance_history_page.dart';
import '../scan/check_page.dart';
import '../shared/home_shell.dart';
import '../shared/today_cards.dart';
import 'leaves_page.dart';

class EmployeeHome extends StatelessWidget {
  const EmployeeHome({super.key});

  @override
  Widget build(BuildContext context) {
    final check = HomeModule(Icons.fingerprint_rounded, 'Chấm công', 'Vị trí, khuôn mặt và mã QR', builder: (_) => const CheckPage());
    final history = HomeModule(Icons.history_rounded, 'Lịch sử', 'Vào ra, đi trễ, về sớm, bảng công tháng', builder: (_) => const AttendanceHistoryPage());
    final leaves = HomeModule(Icons.beach_access_outlined, 'Nghỉ phép', 'Tạo và theo dõi đơn của bạn', builder: (_) => const LeavesPage());
    return HomeShell(
      tagline: 'Quét mã QR tại điểm chấm công để vào ca.',
      modules: [check, history, leaves],
      fab: check,
      shortcuts: [history, leaves],
      summary: (_, token) => EmployeeTodayCard(refreshToken: token),
    );
  }
}

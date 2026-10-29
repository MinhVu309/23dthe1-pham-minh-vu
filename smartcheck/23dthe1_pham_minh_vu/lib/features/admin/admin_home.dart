import 'package:flutter/material.dart';

import '../employee/leaves_page.dart';
import '../manager_qr/qr_display_page.dart';
import '../map/attendance_map_page.dart';
import '../reports/timesheet_page.dart';
import '../shared/home_shell.dart';
import '../shared/today_cards.dart';
import 'departments_page.dart';
import 'employees_page.dart';
import 'fraud_alerts_page.dart';
import 'locations_page.dart';
import 'shifts_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    const manage = 'Quản lý';
    const attendance = 'Chấm công';
    final employees = HomeModule(Icons.groups_2_outlined, 'Nhân viên', 'Tạo, sửa, khoá tài khoản', group: manage, builder: (_) => const EmployeesPage());
    final departments = HomeModule(Icons.apartment_outlined, 'Phòng ban', 'Danh mục phòng ban', group: manage, builder: (_) => const DepartmentsPage());
    final shifts = HomeModule(Icons.schedule_outlined, 'Ca làm việc', 'Giờ vào/ra, ngưỡng đi trễ', group: manage, builder: (_) => const ShiftsPage());
    final locations = HomeModule(Icons.place_outlined, 'Địa điểm', 'Toạ độ và bán kính chấm công', group: manage, builder: (_) => const LocationsPage());
    final qr = HomeModule(Icons.qr_code_2_rounded, 'Điểm chấm công', 'Hiển thị mã QR động', group: attendance, builder: (_) => const QrDisplayPage());
    final sheet = HomeModule(Icons.fact_check_outlined, 'Bảng công', 'Chấm công theo ngày, theo tháng', group: attendance, builder: (_) => const TimesheetPage());
    final map = HomeModule(Icons.map_outlined, 'Bản đồ chấm công', 'Vị trí chấm công của nhân viên', group: attendance, builder: (_) => const AttendanceMapPage());
    final fraud = HomeModule(Icons.gpp_maybe_outlined, 'Cảnh báo gian lận', 'GPS giả, thiết bị lạ', group: attendance, builder: (_) => const FraudAlertsPage());
    final leaves = HomeModule(Icons.beach_access_outlined, 'Đơn nghỉ phép', 'Duyệt hoặc từ chối đơn', group: 'Nghỉ phép', builder: (_) => const LeavesPage());
    return HomeShell(
      tagline: 'Quản trị toàn bộ hệ thống chấm công.',
      modules: [employees, departments, shifts, locations, qr, sheet, map, fraud, leaves],
      fab: qr,
      shortcuts: [employees, sheet],
      summary: (_, token) => StaffTodayCard(refreshToken: token),
    );
  }
}

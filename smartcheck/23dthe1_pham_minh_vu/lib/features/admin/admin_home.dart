import 'package:flutter/material.dart';

import '../employee/leaves_page.dart';
import '../shared/home_shell.dart';
import 'departments_page.dart';
import 'employees_page.dart';
import 'locations_page.dart';
import 'shifts_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) => HomeShell(
        tagline: 'Quản trị toàn bộ hệ thống chấm công.',
        modules: [
          HomeModule(Icons.groups_2_outlined, 'Nhân viên', 'Tạo, sửa, khoá tài khoản', builder: (_) => const EmployeesPage()),
          HomeModule(Icons.apartment_outlined, 'Phòng ban', 'Danh mục phòng ban', builder: (_) => const DepartmentsPage()),
          HomeModule(Icons.schedule_outlined, 'Ca làm việc', 'Giờ vào/ra, ngưỡng đi trễ', builder: (_) => const ShiftsPage()),
          HomeModule(Icons.place_outlined, 'Địa điểm', 'Toạ độ và bán kính chấm công', builder: (_) => const LocationsPage()),
          HomeModule(Icons.beach_access_outlined, 'Đơn nghỉ phép', 'Duyệt hoặc từ chối đơn', builder: (_) => const LeavesPage()),
          HomeModule(Icons.qr_code_2_rounded, 'Điểm chấm công', 'Hiển thị mã QR động'),
          HomeModule(Icons.gpp_maybe_outlined, 'Cảnh báo gian lận', 'GPS giả, thiết bị lạ'),
        ],
      );
}

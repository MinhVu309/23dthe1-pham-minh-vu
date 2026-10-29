import 'package:flutter/material.dart';

import '../shared/home_shell.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) => const HomeShell(
        tagline: 'Quản trị toàn bộ hệ thống chấm công.',
        modules: [
          HomeModule(Icons.groups_2_outlined, 'Nhân viên', 'Tạo, sửa, khoá tài khoản'),
          HomeModule(Icons.apartment_outlined, 'Phòng ban', 'Danh mục phòng ban'),
          HomeModule(Icons.schedule_outlined, 'Ca làm việc', 'Giờ vào/ra, ngưỡng đi trễ'),
          HomeModule(Icons.place_outlined, 'Địa điểm', 'Toạ độ và bán kính chấm công'),
          HomeModule(Icons.beach_access_outlined, 'Đơn nghỉ phép', 'Duyệt hoặc từ chối đơn'),
          HomeModule(Icons.qr_code_2_rounded, 'Điểm chấm công', 'Hiển thị mã QR động'),
          HomeModule(Icons.gpp_maybe_outlined, 'Cảnh báo gian lận', 'GPS giả, thiết bị lạ'),
        ],
      );
}

import 'package:flutter/material.dart';

import '../shared/home_shell.dart';

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) => const HomeShell(
        tagline: 'Theo dõi đội nhóm và điểm chấm công.',
        modules: [
          HomeModule(Icons.qr_code_2_rounded, 'Điểm chấm công', 'Hiển thị mã QR động'),
          HomeModule(Icons.fact_check_outlined, 'Bảng công', 'Chấm công theo ngày, theo tháng'),
          HomeModule(Icons.beach_access_outlined, 'Duyệt nghỉ phép', 'Đơn đang chờ duyệt'),
          HomeModule(Icons.gpp_maybe_outlined, 'Cảnh báo gian lận', 'Xem và xử lý cảnh báo'),
        ],
      );
}

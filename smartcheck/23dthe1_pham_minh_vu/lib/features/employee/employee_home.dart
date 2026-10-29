import 'package:flutter/material.dart';

import '../shared/home_shell.dart';

class EmployeeHome extends StatelessWidget {
  const EmployeeHome({super.key});

  @override
  Widget build(BuildContext context) => const HomeShell(
        tagline: 'Quét mã QR tại điểm chấm công để vào ca.',
        modules: [
          HomeModule(Icons.qr_code_scanner_rounded, 'Chấm công', 'Quét QR, xác thực vị trí và khuôn mặt'),
          HomeModule(Icons.history_rounded, 'Lịch sử chấm công', 'Vào ra, đi trễ, về sớm'),
          HomeModule(Icons.beach_access_outlined, 'Đơn nghỉ phép', 'Tạo và theo dõi đơn của bạn'),
        ],
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';
import 'utils/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Đọc BASE_URL trong .env (không có file thì dùng địa chỉ mặc định theo nền tảng)
  await dotenv.load(fileName: '.env', isOptional: true);
  // Server trả 401 khi đã đăng nhập (token hết hạn) -> tự về màn hình đăng nhập
  ApiClient.onUnauthorized = forceLogout;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '23DTHE1 - Phạm Minh Vũ',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

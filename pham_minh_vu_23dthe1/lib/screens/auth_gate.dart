import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../utils/auth.dart';
import 'admin_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Màn hình khởi động: đọc token đã lưu và chọn màn hình đúng.
///  - Không có token / hết hạn / hỏng / role lạ -> LoginScreen (token xấu đã bị xóa)
///  - Còn hạn + Admin -> AdminScreen; còn hạn + User -> HomeScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<AuthSession?> _session = Auth.currentSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data;
        if (session == null) return const LoginScreen();
        return session.isAdmin ? const AdminScreen() : const HomeScreen();
      },
    );
  }
}

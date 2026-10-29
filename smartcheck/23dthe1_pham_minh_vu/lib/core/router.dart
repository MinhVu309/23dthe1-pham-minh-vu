import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/session.dart';
import '../features/admin/admin_home.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/employee/employee_home.dart';
import '../features/manager_qr/manager_home.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Trang chủ theo role: Admin → quản trị, Manager → dashboard quản lý, Employee → nhân viên.
Widget homeForRole(UserRole role) => switch (role) {
      UserRole.admin => const AdminHome(),
      UserRole.manager => const ManagerHome(),
      UserRole.employee => const EmployeeHome(),
    };

/// Cổng vào của app: chưa rõ trạng thái → màn chờ, chưa đăng nhập → đăng nhập, đã đăng nhập → trang chủ theo role.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthController _auth;
  AuthStatus? _last;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _auth.addListener(_onChange);
  }

  @override
  void dispose() {
    _auth.removeListener(_onChange);
    super.dispose();
  }

  /// Khi bị đăng xuất (kể cả do 401 lúc đang ở màn con), đóng hết màn con để thấy màn đăng nhập.
  void _onChange() {
    if (_last == AuthStatus.signedIn && _auth.status == AuthStatus.signedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
      });
    }
    _last = _auth.status;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(
          backgroundColor: AppColors.ink,
          body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
        ),
      AuthStatus.signedOut => const LoginPage(),
      AuthStatus.signedIn => homeForRole(auth.session!.role),
    };
  }
}

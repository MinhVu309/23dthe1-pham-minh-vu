import 'package:flutter/material.dart';

import '../utils/auth.dart';
import '../utils/jwt_claims.dart';
import '../widgets/error_view.dart';
import 'admin_screen.dart';
import 'home_screen.dart';
import 'registration_screen.dart';

/// Màn hình đăng nhập. [notice] là thông báo hiện khi vừa bị đăng xuất (VD token hết hạn).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});

  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSnack(context, notice, error: true);
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      showSnack(context, 'Vui lòng nhập đầy đủ thông tin', error: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await Auth.login(username, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] != true) {
      showSnack(context, '${result['message'] ?? 'Tên đăng nhập hoặc mật khẩu không đúng'}', error: true);
      return;
    }

    // Vai trò lấy từ token đã giải mã: Admin vào trang Admin, User vào trang chính
    final Widget next;
    switch (result['role']) {
      case adminRole:
        next = const AdminScreen();
      case userRole:
        next = const HomeScreen();
      default:
        showSnack(context, 'Tài khoản không có quyền hợp lệ', error: true);
        return;
    }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => next), (route) => false);
  }

  Future<void> _openRegistration() async {
    // Đăng ký xong trả về tên đăng nhập để điền sẵn
    final username = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
    );
    if (username != null && mounted) {
      _usernameController.text = username;
      _passwordController.clear();
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffixIcon, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),
                Icon(Icons.storefront, size: 64, color: color),
                const SizedBox(height: 12),
                Text(
                  '23DTHE1 - Phạm Minh Vũ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Tên đăng nhập', prefixIcon: const Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _isLoading ? null : _handleLogin(),
                  decoration: _decoration(
                    'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? '),
                    TextButton(onPressed: _openRegistration, child: const Text('Đăng ký ngay')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

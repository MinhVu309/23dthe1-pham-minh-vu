import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';

import '../utils/auth.dart';
import '../utils/jwt_claims.dart';
import '../widgets/error_view.dart';

/// Màn hình đăng ký. Đăng ký thành công thì pop về LoginScreen kèm tên đăng nhập.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _initialsController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = userRole;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _initialsController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // smart_auth (Phone Number Hint của Google Play services) chỉ có trên Android
  bool get _canUsePhoneHint => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Hiện hộp thoại gợi ý số điện thoại (SIM) của hệ thống và điền vào ô số điện thoại.
  Future<void> _pickPhoneNumber() async {
    try {
      final result = await SmartAuth.instance.requestPhoneNumberHint();
      if (!mounted) return;
      if (result.hasData) {
        _phoneController.text = result.data!;
      } else if (!result.isCanceled) {
        // Không có SIM/tài khoản Google (VD emulator) hoặc Play services lỗi
        showSnack(context, 'Không lấy được số điện thoại từ thiết bị, hãy nhập tay', error: true);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Thiết bị không hỗ trợ gợi ý số điện thoại, hãy nhập tay', error: true);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await Auth.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      initials: _initialsController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      role: _role,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showSnack(context, '${result['message'] ?? 'Đăng ký thành công!'}');
      Navigator.pop(context, _usernameController.text.trim());
    } else {
      // Hiện đúng thông báo lỗi của server (trùng tên, mật khẩu yếu...)
      showSnack(context, '${result['message'] ?? 'Đăng ký thất bại'}', error: true);
    }
  }

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
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
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Đăng ký tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tạo tài khoản mới',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Tên đăng nhập'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đăng nhập' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Email'),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Vui lòng nhập email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Mật khẩu',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    'Gồm chữ hoa, chữ thường, số và ký tự đặc biệt (VD: Abc@12345)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _initialsController,
                  maxLength: 5,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Ký tự viết tắt (tối đa 5 ký tự)'),
                ),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Số điện thoại (không bắt buộc)',
                    suffixIcon: _canUsePhoneHint
                        ? IconButton(
                            tooltip: 'Lấy số điện thoại từ thiết bị',
                            icon: const Icon(Icons.sim_card_outlined),
                            onPressed: _pickPhoneNumber,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: _decoration('Vai trò'),
                  items: const [
                    DropdownMenuItem(value: userRole, child: Text('User')),
                    DropdownMenuItem(value: adminRole, child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? userRole),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Đăng ký', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản? '),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đăng nhập')),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import 'auth_controller.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Khớp luật mật khẩu của server (Identity): tối thiểu 6 ký tự, có chữ thường và chữ số.
/// Server vẫn là nơi quyết định; đây chỉ để báo lỗi sớm.
String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Nhập mật khẩu';
  if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Cần ít nhất một chữ thường';
  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Cần ít nhất một chữ số';
  return null;
}

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Nhập email';
  if (!_emailRe.hasMatch(v.trim())) return 'Email không hợp lệ';
  return null;
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      final message = await context.read<AuthController>().register(_email.text, _password.text, _name.text);
      nav.pop(message); // màn đăng nhập hiển thị thông báo thành công
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      showBack: true,
      title: 'Tạo tài khoản',
      subtitle: 'Tài khoản mới mặc định là Nhân viên.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) NoticeBanner(_error!),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập họ và tên' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                helperText: 'Tối thiểu 6 ký tự, gồm chữ thường và chữ số',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset_rounded)),
              validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'Đăng ký', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

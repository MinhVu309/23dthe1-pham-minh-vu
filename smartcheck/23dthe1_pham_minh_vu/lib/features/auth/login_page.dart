import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/biometric_service.dart';
import '../../services/google_auth_service.dart';
import 'auth_controller.dart';
import 'otp_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  String? _info;
  bool _bioBusy = false;
  BiometricOption? _bio;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _info = auth.takeNotice();
    auth.biometricOption().then((o) {
      if (mounted) setState(() => _bio = o);
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = context.read<AuthController>();
    try {
      final sentOtp = await auth.login(_id.text, _password.text);
      if (!mounted) return;
      if (!sentOtp) {
        setState(() => _error = 'Máy chủ không gửi mã OTP. Hãy thử lại.');
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpPage(identifier: _id.text.trim())));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    final auth = context.read<AuthController>();
    setState(() {
      _bioBusy = true;
      _error = null;
      _info = null;
    });
    try {
      await auth.loginWithBiometric();
    } on BiometricCancelled {
      // người dùng tự đóng hộp thoại quét
    } on BiometricFailed catch (e) {
      final label = _bio?.label ?? 'sinh trắc học';
      if (mounted) {
        setState(() {
          if (e.permanent) {
            _bio = null;
            _error = 'Máy này không còn dùng được $label (có thể bạn đã xoá vân tay/khuôn mặt). Hãy đăng nhập bằng mật khẩu và OTP.';
          } else {
            _error = 'Chưa xác thực được bằng $label, hãy thử lại hoặc dùng mật khẩu.';
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        // 401/403: token đã bị xoá, nút sẽ biến mất.
        final gone = e.status == 401 || e.status == 403;
        setState(() {
          _error = e.message;
          if (gone) _bio = null;
        });
      }
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<AuthController>().signInWithGoogle();
    } on GoogleNotConfigured catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on GoogleCancelled {
      // người dùng tự đóng hộp thoại, không cần báo lỗi
    } on GoogleSignInFailed catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập Google thất bại (${e.detail}).');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  void _openForgotPassword() {
    final typed = _id.text.trim();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ForgotPasswordPage(initialEmail: typed.contains('@') ? typed : '')));
  }

  Future<void> _openRegister() async {
    final message = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const RegisterPage()));
    if (message != null && mounted) {
      setState(() {
        _info = message;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'SmartCheck',
      subtitle: 'Chấm công đúng người, đúng chỗ, đúng giờ.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_info != null) NoticeBanner(_info!, isError: false),
            if (_error != null) NoticeBanner(_error!),
            if (_bio != null) ...[
              FilledButton.icon(
                onPressed: (_busy || _bioBusy) ? null : _biometric,
                icon: _bioBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fingerprint_rounded, size: 28),
                label: Text('Đăng nhập bằng ${_bio!.label}'),
              ),
              const SizedBox(height: 6),
              Text(
                'Xin chào ${_bio!.fullName.isEmpty ? _bio!.email : _bio!.fullName}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('hoặc dùng mật khẩu', style: TextStyle(color: AppColors.textMuted)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _id,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Email hoặc tên đăng nhập', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập email hoặc tên đăng nhập' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _openForgotPassword, child: const Text('Quên mật khẩu?')),
            ),
            const SizedBox(height: 6),
            BusyButton(label: 'Đăng nhập', busy: _busy, onPressed: _submit),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('hoặc', style: TextStyle(color: AppColors.textMuted)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: (_busy || _googleBusy) ? null : _google,
              icon: _googleBusy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.g_mobiledata_rounded, size: 30),
              label: const Text('Tiếp tục với Google'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Chưa có tài khoản?', style: TextStyle(color: AppColors.textMuted)),
                TextButton(onPressed: _openRegister, child: const Text('Đăng ký')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

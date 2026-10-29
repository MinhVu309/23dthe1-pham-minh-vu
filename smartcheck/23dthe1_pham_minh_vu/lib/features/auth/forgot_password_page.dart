import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'auth_controller.dart';
import 'otp_page.dart' show formatCountdown;
import 'register_page.dart' show validateEmail, validatePassword;

/// Server bỏ qua yêu cầu gửi mã lại trong vòng 1 phút, nên nút "Gửi lại" chờ đúng bằng đó.
const _resendCooldown = Duration(seconds: 60);

/// Quên mật khẩu, hai bước: (1) nhập email để nhận mã xác minh; (2) nhập mã + mật khẩu mới.
/// Đổi xong là đăng nhập luôn (người nhập đúng mã đã chứng tỏ giữ hộp thư).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false; // false = bước 1, true = bước 2
  bool _hide = true;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  Timer? _ticker;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  Duration _left = AppConfig.otpValidity;
  Duration _resendLeft = _resendCooldown;

  @override
  void dispose() {
    _ticker?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startTimers() {
    final now = nowProvider();
    _expiresAt = now.add(AppConfig.otpValidity);
    _resendAt = now.add(_resendCooldown);
    _left = AppConfig.otpValidity;
    _resendLeft = _resendCooldown;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final t = nowProvider();
      if (mounted) {
        setState(() {
          _left = _expiresAt.difference(t);
          _resendLeft = _resendAt.difference(t);
        });
      }
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_emailForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      if (resend) {
        _resending = true;
      } else {
        _busy = true;
      }
      _error = null;
      _info = null;
    });
    try {
      final message = await context.read<AuthController>().forgotPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = resend ? 'Đã gửi lại mã, hãy kiểm tra email.' : message;
        _startTimers();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _resending = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final nav = Navigator.of(context);
    try {
      await context.read<AuthController>().resetPassword(_email.text, _code.text, _password.text);
      // AuthGate đã chuyển sang trang chủ phía dưới; đóng các màn đăng nhập đang chồng lên.
      nav.popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeEmail() => setState(() {
        _codeSent = false;
        _error = null;
        _info = null;
        _code.clear();
      });

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      showBack: true,
      title: 'Quên mật khẩu',
      subtitle: _codeSent ? 'Nhập mã đã gửi tới ${_email.text.trim()} và đặt mật khẩu mới.' : 'Nhập email của tài khoản để nhận mã xác minh.',
      child: _codeSent ? _resetStep() : _emailStep(),
    );
  }

  Widget _emailStep() => Form(
        key: _emailForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) NoticeBanner(_error!),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofocus: widget.initialEmail.isEmpty,
              onFieldSubmitted: (_) => _sendCode(),
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 22),
            BusyButton(label: 'Gửi mã xác minh', busy: _busy, onPressed: _sendCode),
          ],
        ),
      );

  Widget _resetStep() {
    final expired = _left <= Duration.zero;
    return Form(
      key: _resetForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_info != null) NoticeBanner(_info!, isError: false),
          if (_error != null) NoticeBanner(_error!),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700, color: AppColors.ink),
            decoration: const InputDecoration(counterText: '', hintText: '••••••', labelText: 'Mã 6 số'),
            validator: (v) => (v == null || v.trim().length != 6) ? 'Nhập đủ 6 số của mã' : null,
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.timer_outlined, size: 18, color: expired ? AppColors.danger : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(expired ? 'Mã đã hết hạn, hãy gửi lại' : 'Mã hết hạn sau ${formatCountdown(_left)}',
                style: TextStyle(color: expired ? AppColors.danger : AppColors.textMuted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
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
            onFieldSubmitted: (_) => _reset(),
            decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới', prefixIcon: Icon(Icons.lock_reset_rounded)),
            validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
          ),
          const SizedBox(height: 22),
          BusyButton(label: 'Đổi mật khẩu', busy: _busy, onPressed: _reset),
          const SizedBox(height: 10),
          TextButton(
            onPressed: (_resendLeft > Duration.zero || _resending || _busy) ? null : () => _sendCode(resend: true),
            child: Text(_resendLeft > Duration.zero ? 'Gửi lại mã sau ${_resendLeft.inSeconds}s' : 'Gửi lại mã'),
          ),
          TextButton(onPressed: _busy ? null : _changeEmail, child: const Text('Đổi email khác')),
        ],
      ),
    );
  }
}

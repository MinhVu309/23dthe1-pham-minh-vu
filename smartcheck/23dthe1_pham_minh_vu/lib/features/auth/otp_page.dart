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

String formatCountdown(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.identifier});

  /// Email/tên đăng nhập đã nhập ở bước 1.
  final String identifier;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _code = TextEditingController();
  Timer? _ticker;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  Duration _left = AppConfig.otpValidity;
  Duration _resendLeft = AppConfig.otpResendCooldown;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _restartTimers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _restartTimers() {
    final now = nowProvider();
    _expiresAt = now.add(AppConfig.otpValidity);
    _resendAt = now.add(AppConfig.otpResendCooldown);
    _left = AppConfig.otpValidity;
    _resendLeft = AppConfig.otpResendCooldown;
  }

  void _tick() {
    final now = nowProvider();
    setState(() {
      _left = _expiresAt.difference(now);
      _resendLeft = _resendAt.difference(now);
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_busy) return;
    if (code.length != 6) {
      setState(() => _error = 'Nhập đủ 6 số của mã OTP.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final nav = Navigator.of(context);
    try {
      await auth.verifyOtp(widget.identifier, code);
      // AuthGate đã chuyển sang trang chủ phía dưới; đóng các màn đăng nhập đang chồng lên.
      nav.popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<AuthController>().resendOtp(widget.identifier);
      if (!mounted) return;
      setState(() {
        _restartTimers();
        _info = 'Đã gửi lại mã OTP, hãy kiểm tra email.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _left <= Duration.zero;
    return AuthShell(
      showBack: true,
      title: 'Nhập mã OTP',
      subtitle: 'Mã 6 số đã gửi tới email của tài khoản ${widget.identifier}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_info != null) NoticeBanner(_info!, isError: false),
          if (_error != null) NoticeBanner(_error!),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 30, letterSpacing: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: expired ? AppColors.danger : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                expired ? 'Mã đã hết hạn, hãy gửi lại' : 'Mã hết hạn sau ${formatCountdown(_left)}',
                style: TextStyle(color: expired ? AppColors.danger : AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 22),
          BusyButton(label: 'Xác nhận', busy: _busy, onPressed: _verify),
          const SizedBox(height: 12),
          TextButton(
            onPressed: (_resendLeft > Duration.zero || _resending || _busy) ? null : _resend,
            child: Text(_resendLeft > Duration.zero ? 'Gửi lại mã sau ${_resendLeft.inSeconds}s' : 'Gửi lại mã'),
          ),
        ],
      ),
    );
  }
}

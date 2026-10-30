import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../services/biometric_service.dart';
import 'auth_controller.dart';

/// Lời mời bật đăng nhập sinh trắc, hiện một lần sau khi đăng nhập bằng mật khẩu + OTP.
/// [label] là cách gọi trong câu chữ ("vân tay", "khuôn mặt"…).
Future<void> offerBiometric(BuildContext context, AuthController auth, String label) async {
  final messenger = ScaffoldMessenger.of(context);
  final accept = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.fingerprint_rounded, size: 40),
      title: Text('Đăng nhập nhanh bằng $label?'),
      content: Text(
        'Lần sau bạn có thể đăng nhập bằng $label của điện thoại thay vì nhập mật khẩu và mã OTP. '
        'Bạn có thể tắt bất cứ lúc nào.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Để sau')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Bật ngay')),
      ],
    ),
  );
  if (accept != true) {
    await auth.declineBiometricOffer();
    return;
  }
  await enableBiometricWithFeedback(messenger, auth, label);
}

/// Bật đăng nhập sinh trắc và báo kết quả bằng SnackBar. Trả `true` nếu bật được.
Future<bool> enableBiometricWithFeedback(ScaffoldMessengerState messenger, AuthController auth, String label) async {
  try {
    await auth.enableBiometric();
    messenger.showSnackBar(SnackBar(content: Text('Đã bật đăng nhập bằng $label.')));
    return true;
  } on BiometricCancelled {
    messenger.showSnackBar(const SnackBar(content: Text('Chưa bật đăng nhập sinh trắc học.')));
  } on BiometricFailed {
    messenger.showSnackBar(const SnackBar(content: Text('Không bật được đăng nhập sinh trắc học trên máy này.')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
  return false;
}

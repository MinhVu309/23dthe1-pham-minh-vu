import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/services/google_auth_service.dart';

void main() {
  group('googleUnavailableReason (chặn trước khi gọi thư viện Google)', () {
    test('thiếu client ID Web thì không dùng được trên mọi nền tảng', () {
      for (final ios in [true, false]) {
        expect(googleUnavailableReason(isIOS: ios, serverClientId: '', iosClientId: 'ios-id'), contains('thiếu Google client ID'));
      }
    });

    test('Android chỉ cần client ID Web', () {
      expect(googleUnavailableReason(isIOS: false, serverClientId: 'web-id', iosClientId: ''), isNull);
    });

    test('iOS thiếu client ID iOS thì bị chặn với thông báo tiếng Việt (tránh app sập)', () {
      final r = googleUnavailableReason(isIOS: true, serverClientId: 'web-id', iosClientId: '');
      expect(r, contains('iPhone'));
      expect(r, contains('email'));
    });

    test('iOS có đủ hai client ID thì cho dùng', () {
      expect(googleUnavailableReason(isIOS: true, serverClientId: 'web-id', iosClientId: 'ios-id'), isNull);
    });
  });

  test('GoogleNotConfigured mặc định có thông báo cũ', () {
    expect(GoogleNotConfigured().message, 'Đăng nhập Google chưa được cấu hình (thiếu Google client ID).');
  });
}

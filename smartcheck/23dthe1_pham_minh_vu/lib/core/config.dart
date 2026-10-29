/// Mọi cấu hình của app nằm ở đây. Có thể ghi đè lúc build:
/// `flutter run --dart-define=BASE_URL=https://...`
class AppConfig {
  AppConfig._();

  /// URL API đã deploy (https). Không dùng localhost / 10.0.2.2.
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://vupham309-001-site1.etempurl.com',
  );

  /// OAuth *Web* client ID (cùng giá trị với `Google:ClientId` của backend).
  /// Để trống thì nút Google báo "chưa cấu hình".
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  // Host miễn phí ngủ khi nhàn rỗi nên request đầu có thể chậm.
  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 45);

  /// OTP hết hạn sau 5 phút (khớp backend).
  static const otpValidity = Duration(minutes: 5);
  static const otpResendCooldown = Duration(seconds: 30);
}

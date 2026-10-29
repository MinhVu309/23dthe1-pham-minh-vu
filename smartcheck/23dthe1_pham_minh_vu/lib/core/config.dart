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
  /// Client ID không phải bí mật. Để trống thì nút Google báo "chưa cấu hình".
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '185827252320-ccaml6efko4me8d6nudimasb7kmft1cg.apps.googleusercontent.com',
  );

  /// OAuth *iOS* client ID (tạo trong Google Cloud với bundle id `com.phamminhvu.chamcong`).
  /// Để trống thì nút Google bị chặn trên iPhone. Khi điền phải thêm cả `GIDClientID` và URL scheme
  /// (client ID đảo ngược) vào `ios/Runner/Info.plist`, nếu không thư viện Google sẽ làm app sập.
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');

  // Host miễn phí ngủ khi nhàn rỗi nên request đầu có thể chậm.
  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 45);

  /// Màn "Điểm chấm công" lấy QR mới theo chu kỳ này (token sống ~45 s nên luôn còn hạn).
  static const qrRefresh = Duration(seconds: 30);

  /// OTP hết hạn sau 5 phút (khớp backend).
  static const otpValidity = Duration(minutes: 5);
  static const otpResendCooldown = Duration(seconds: 30);
}

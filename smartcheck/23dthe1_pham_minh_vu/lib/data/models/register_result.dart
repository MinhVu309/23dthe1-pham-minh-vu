/// Kết quả `POST /api/auth/register`.
class RegisterResult {
  const RegisterResult({required this.message, this.requiresEmailVerification = false});

  final String message;

  /// `true` khi server đã gửi mã xác minh tới email: phải nhập mã (gọi `verify-otp`) mới hoàn tất đăng ký.
  /// Server cũ chưa có bước này thì trường không có và giá trị là `false`.
  final bool requiresEmailVerification;
}

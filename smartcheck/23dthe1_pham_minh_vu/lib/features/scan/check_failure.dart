import '../../core/api_client.dart';

/// Lỗi chấm công đã đổi thành tiêu đề + hướng dẫn tiếng Việt theo `code` của server.
class CheckFailure {
  const CheckFailure({required this.title, required this.message, this.reasons = const [], this.retryable = true});

  final String title;
  final String message;
  final List<String> reasons;

  /// `true` nếu quét lại có thể khắc phục (QR cũ, ngoài phạm vi...).
  final bool retryable;

  factory CheckFailure.from(ApiException e) {
    if (e.isNetwork) {
      return CheckFailure(title: 'Không kết nối được', message: e.message);
    }
    switch (e.code) {
      case 'QR_INVALID':
        return CheckFailure(
          title: 'Mã QR không dùng được',
          message: '${e.message}. Hãy quét lại mã đang hiển thị trên màn hình điểm chấm công.',
        );
      case 'LOCATION_NOT_FOUND':
        return CheckFailure(title: 'Địa điểm không tồn tại', message: e.message, retryable: false);
      case 'OUT_OF_RANGE':
        return CheckFailure(title: 'Ngoài phạm vi chấm công', message: e.message);
      case 'FRAUD_SUSPECTED':
        return CheckFailure(
          title: 'Nghi ngờ gian lận',
          message: 'Hệ thống từ chối chấm công và đã ghi nhận cảnh báo cho quản lý.',
          reasons: e.reasons,
          retryable: false,
        );
      case 'FACE_REQUIRED':
        return const CheckFailure(
          title: 'Cần xác thực khuôn mặt',
          message: 'Tài khoản của bạn đã đăng ký khuôn mặt nên phải xác thực khuôn mặt mới chấm công được.',
        );
      case 'FACE_MISMATCH':
        return const CheckFailure(
          title: 'Khuôn mặt không khớp',
          message: 'Khuôn mặt vừa quét không trùng với khuôn mặt đã đăng ký. Đã ghi nhận cảnh báo cho quản lý.',
          retryable: false,
        );
      case 'ALREADY_DONE':
        return CheckFailure(title: 'Bạn đã chấm công rồi', message: e.message, retryable: false);
      case 'NO_CHECKIN':
        return CheckFailure(title: 'Chưa chấm công vào', message: '${e.message}. Hãy chấm công vào ca trước khi ra ca.', retryable: false);
    }
    if (e.status == 403) return CheckFailure(title: 'Không có quyền', message: e.message, reasons: e.reasons, retryable: false);
    return CheckFailure(title: 'Chấm công không thành công', message: e.message);
  }
}

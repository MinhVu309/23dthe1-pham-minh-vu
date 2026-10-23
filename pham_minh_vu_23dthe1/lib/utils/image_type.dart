/// Nhận diện định dạng ảnh THẬT từ vài byte đầu tệp (giống cách server kiểm tra).
///
/// Cần thiết vì `image_picker` khi nén/thu nhỏ có thể trả về dữ liệu JPEG nhưng vẫn đặt tên "scaled_27.png";
/// server kiểm tra cả đuôi lẫn nội dung nên sẽ từ chối. Ta đặt lại đuôi tên tệp theo nội dung thật trước khi upload.
///
/// Trả về ".jpg", ".png" hoặc ".webp"; null nếu không phải ba định dạng này.
String? detectImageExtension(List<int> header) {
  bool startsWith(List<int> sig, {int offset = 0}) {
    if (header.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (header[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return '.jpg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return '.png';
  // WEBP: "RIFF" .... "WEBP"
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return '.webp';
  }
  return null;
}

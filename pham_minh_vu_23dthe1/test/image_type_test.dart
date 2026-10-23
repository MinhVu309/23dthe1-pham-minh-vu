import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/utils/image_type.dart';

void main() {
  group('detectImageExtension (nhận diện theo nội dung, không theo tên tệp)', () {
    test('JPEG', () => expect(detectImageExtension([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x6A]), '.jpg'));

    test('PNG', () => expect(detectImageExtension([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]), '.png'));

    test('WEBP', () {
      final header = [...'RIFF'.codeUnits, 0x1A, 0, 0, 0, ...'WEBP'.codeUnits];
      expect(detectImageExtension(header), '.webp');
    });

    test('RIFF không phải WEBP (VD WAV) bị từ chối', () {
      final header = [...'RIFF'.codeUnits, 0x1A, 0, 0, 0, ...'WAVE'.codeUnits];
      expect(detectImageExtension(header), isNull);
    });

    test('GIF, tệp thực thi, rỗng hoặc quá ngắn đều không được nhận', () {
      expect(detectImageExtension('GIF89a'.codeUnits), isNull);
      expect(detectImageExtension('MZ\x90\x00'.codeUnits), isNull);
      expect(detectImageExtension(const []), isNull);
      expect(detectImageExtension(const [0xFF, 0xD8]), isNull);
    });
  });
}

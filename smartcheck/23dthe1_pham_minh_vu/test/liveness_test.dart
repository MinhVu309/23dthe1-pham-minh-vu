import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/features/face/liveness.dart';

const _none = FaceSample.none();
FaceSample _eyes(double l, double r) => FaceSample(faces: 1, leftEyeOpen: l, rightEyeOpen: r, yaw: 0);
FaceSample _yaw(double y) => FaceSample(faces: 1, leftEyeOpen: 0.9, rightEyeOpen: 0.9, yaw: y);
const _open = FaceSample(faces: 1, leftEyeOpen: 0.95, rightEyeOpen: 0.95, yaw: 0);

LivenessDetector _blink() => LivenessDetector(LivenessKind.blink);
LivenessDetector _turn() => LivenessDetector(LivenessKind.turnHead);

void _feed(LivenessDetector d, FaceSample s, [int times = 1]) {
  for (var i = 0; i < times; i++) {
    d.update(s);
  }
}

void main() {
  group('Chung', () {
    test('không có mặt → noFace; nhiều mặt → multipleFaces', () {
      final d = _blink();
      expect(d.update(_none), LivenessPhase.noFace);
      expect(d.update(const FaceSample(faces: 2, leftEyeOpen: 0.9, rightEyeOpen: 0.9)), LivenessPhase.multipleFaces);
      expect(d.message, 'Chỉ để một khuôn mặt trong khung hình');
    });

    test('lời nhắc: lấy mốc → "Nhìn thẳng"; sau đó là lời nhắc theo thử thách', () {
      final d = _blink();
      d.update(_open);
      expect(d.phase, LivenessPhase.lookStraight);
      expect(d.message, 'Nhìn thẳng vào camera');
      _feed(d, _open, 3);
      expect(d.phase, LivenessPhase.action);
      expect(d.message, 'Hãy chớp mắt');
      expect(_turn().kind.instruction, 'Hãy quay đầu sang một bên');
    });

    test('đã passed thì giữ nguyên dù khung hình sau là gì', () {
      final d = _turn();
      _feed(d, _yaw(0), 3);
      d.update(_yaw(40));
      expect(d.passed, isTrue);
      expect(d.update(const FaceSample(faces: 2)), LivenessPhase.passed);
      expect(d.update(_none), LivenessPhase.passed);
    });

    test('LivenessKind.random chọn được cả hai loại', () {
      final seen = <LivenessKind>{for (var i = 0; i < 200; i++) LivenessKind.random()};
      expect(seen, LivenessKind.values.toSet());
    });
  });

  group('Chớp mắt', () {
    test('mở → nhắm → mở lại thì vượt qua', () {
      final d = _blink();
      _feed(d, _open, 3);
      expect(d.passed, isFalse);
      _feed(d, _eyes(0.05, 0.1), 2);
      expect(d.passed, isFalse);
      d.update(_open);
      expect(d.passed, isTrue);
      expect(d.message, 'Xác thực thành công');
    });

    test('ảnh tĩnh (mắt luôn mở) không bao giờ vượt qua', () {
      final d = _blink();
      _feed(d, _open, 500);
      expect(d.passed, isFalse);
    });

    test('mắt nhắm sẵn từ đầu rồi mở ra không tính: phải có mốc "mở" trước', () {
      final d = _blink();
      _feed(d, _eyes(0.05, 0.05), 10);
      _feed(d, _open, 2); // mới 2 khung mở, chưa đủ mốc
      expect(d.passed, isFalse);
    });

    test('chỉ nhắm một mắt (nháy) không tính là chớp', () {
      final d = _blink();
      _feed(d, _open, 3);
      _feed(d, _eyes(0.05, 0.9), 3);
      d.update(_open);
      expect(d.passed, isFalse);
    });

    test('nhắm nửa chừng (0.5) không tính là nhắm', () {
      final d = _blink();
      _feed(d, _open, 3);
      _feed(d, _eyes(0.5, 0.5), 5);
      d.update(_open);
      expect(d.passed, isFalse);
    });

    test('không có số liệu mắt thì không tiến triển', () {
      final d = _blink();
      _feed(d, const FaceSample(faces: 1, yaw: 0), 50);
      expect(d.passed, isFalse);
      expect(d.phase, LivenessPhase.lookStraight);
    });

    test('mất mặt thoáng qua lúc nhắm mắt vẫn giữ tiến độ', () {
      final d = _blink();
      _feed(d, _open, 3);
      d.update(_eyes(0.05, 0.05));
      _feed(d, _none, 2); // ML Kit mất mặt vài khung khi nhắm
      d.update(_open);
      expect(d.passed, isTrue);
    });

    test('mất mặt lâu thì làm lại từ đầu', () {
      final d = _blink();
      _feed(d, _open, 3);
      d.update(_eyes(0.05, 0.05));
      _feed(d, _none, 5); // quá ngưỡng cho phép
      expect(d.phase, LivenessPhase.noFace);
      d.update(_open); // tiến độ đã mất: phải lấy mốc lại
      expect(d.passed, isFalse);
    });

    test('xuất hiện người thứ hai giữa chừng thì làm lại ngay', () {
      final d = _blink();
      _feed(d, _open, 3);
      d.update(_eyes(0.05, 0.05));
      d.update(const FaceSample(faces: 2, leftEyeOpen: 0.9, rightEyeOpen: 0.9));
      d.update(_open);
      expect(d.passed, isFalse);
      expect(d.phase, LivenessPhase.lookStraight);
    });
  });

  group('Quay đầu', () {
    test('nhìn thẳng rồi quay quá 25° (một trong hai phía) thì vượt qua', () {
      for (final angle in [30.0, -30.0]) {
        final d = _turn();
        _feed(d, _yaw(2), 3);
        d.update(_yaw(angle));
        expect(d.passed, isTrue, reason: 'yaw $angle');
      }
    });

    test('quay chưa đủ góc (20°) thì chưa qua', () {
      final d = _turn();
      _feed(d, _yaw(0), 3);
      _feed(d, _yaw(20), 20);
      expect(d.passed, isFalse);
      expect(d.phase, LivenessPhase.action);
    });

    test('mặt nghiêng sẵn từ đầu không tính: phải nhìn thẳng đủ số khung trước', () {
      final d = _turn();
      _feed(d, _yaw(40), 10);
      expect(d.passed, isFalse);
      expect(d.phase, LivenessPhase.lookStraight);
    });

    test('đang lấy mốc mà quay lệch thì đếm lại từ đầu', () {
      final d = _turn();
      _feed(d, _yaw(0), 2);
      d.update(_yaw(18)); // lệch khỏi ±12° → reset bộ đếm
      d.update(_yaw(0));
      expect(d.phase, LivenessPhase.lookStraight); // mới 1 khung thẳng sau khi lệch
    });

    test('không có góc quay thì không tiến triển', () {
      final d = _turn();
      _feed(d, const FaceSample(faces: 1, leftEyeOpen: 0.9, rightEyeOpen: 0.9), 30);
      expect(d.passed, isFalse);
    });
  });
}

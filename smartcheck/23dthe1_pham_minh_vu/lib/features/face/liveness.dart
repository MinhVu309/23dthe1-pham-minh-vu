import 'dart:math';

/// Thử thách xác thực "người thật": chớp mắt hoặc quay đầu. Ảnh chụp tĩnh không làm được.
enum LivenessKind {
  blink('Hãy chớp mắt'),
  turnHead('Hãy quay đầu sang một bên');

  const LivenessKind(this.instruction);
  final String instruction;

  static LivenessKind random([Random? rng]) => values[(rng ?? Random()).nextInt(values.length)];
}

/// Điều app đang chờ ở người dùng, dùng để hiện hướng dẫn.
enum LivenessPhase {
  noFace('Đưa khuôn mặt vào khung hình'),
  multipleFaces('Chỉ để một khuôn mặt trong khung hình'),
  lookStraight('Nhìn thẳng vào camera'),
  action(''), // lời nhắc phụ thuộc thử thách, lấy từ LivenessKind.instruction
  passed('Xác thực thành công');

  const LivenessPhase(this.message);
  final String message;
}

/// Kết quả nhận diện của một khung hình (lấy từ ML Kit). Các giá trị `null` nghĩa là không có số liệu.
class FaceSample {
  const FaceSample({required this.faces, this.leftEyeOpen, this.rightEyeOpen, this.yaw});

  const FaceSample.none() : this(faces: 0);

  /// Số khuôn mặt thấy trong khung hình.
  final int faces;

  /// Xác suất mắt đang mở, 0..1.
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Góc quay đầu quanh trục dọc, độ. Dương/âm là hai phía; chỉ dùng độ lớn.
  final double? yaw;
}

/// Máy trạng thái xác thực: phải **nhìn thẳng một lúc** (mốc so sánh) rồi mới thực hiện động tác.
/// Đúng một khuôn mặt; thấy 0 hoặc ≥ 2 khuôn mặt thì làm lại từ đầu.
class LivenessDetector {
  LivenessDetector(this.kind, {this.baselineFrames = 3, this.missingTolerance = 4});

  final LivenessKind kind;

  /// Số khung hình liên tiếp được phép mất mặt (ML Kit đôi lúc mất mặt đúng lúc nhắm mắt) trước khi làm lại.
  final int missingTolerance;

  /// Số khung hình liên tiếp phải ở tư thế mốc trước khi tính động tác.
  final int baselineFrames;

  static const eyeOpenAbove = 0.7;
  static const eyeClosedBelow = 0.3;
  static const straightWithin = 12.0; // độ
  static const turnedBeyond = 25.0; // độ

  LivenessPhase phase = LivenessPhase.noFace;
  int _stage = 0; // 0 = lấy mốc, 1 = chờ động tác (chớp: nhắm / quay: quay đủ góc), 2 = chớp: chờ mở lại
  int _stable = 0;
  int _missing = 0;

  bool get passed => phase == LivenessPhase.passed;

  String get message => phase == LivenessPhase.action ? kind.instruction : phase.message;

  void reset() {
    _stage = 0;
    _stable = 0;
    _missing = 0;
    phase = LivenessPhase.noFace;
  }

  LivenessPhase update(FaceSample s) {
    if (passed) return phase;
    if (s.faces == 0) {
      // Mất mặt thoáng qua thì giữ tiến độ; mất lâu mới làm lại.
      if (++_missing > missingTolerance) reset();
      return phase;
    }
    _missing = 0;
    if (s.faces > 1) {
      reset();
      return phase = LivenessPhase.multipleFaces;
    }
    return phase = switch (kind) {
      LivenessKind.blink => _blink(s),
      LivenessKind.turnHead => _turn(s),
    };
  }

  LivenessPhase _blink(FaceSample s) {
    final l = s.leftEyeOpen, r = s.rightEyeOpen;
    if (l == null || r == null) return _hold();
    final open = l > eyeOpenAbove && r > eyeOpenAbove;
    final closed = l < eyeClosedBelow && r < eyeClosedBelow;
    switch (_stage) {
      case 0:
        _stable = open ? _stable + 1 : 0;
        if (_stable >= baselineFrames) _stage = 1;
      case 1:
        if (closed) _stage = 2;
      case 2:
        if (open) return LivenessPhase.passed;
    }
    return _hold();
  }

  LivenessPhase _turn(FaceSample s) {
    final yaw = s.yaw;
    if (yaw == null) return _hold();
    switch (_stage) {
      case 0:
        _stable = yaw.abs() < straightWithin ? _stable + 1 : 0;
        if (_stable >= baselineFrames) _stage = 1;
      case 1:
        if (yaw.abs() >= turnedBeyond) return LivenessPhase.passed;
    }
    return _hold();
  }

  LivenessPhase _hold() => _stage == 0 ? LivenessPhase.lookStraight : LivenessPhase.action;
}

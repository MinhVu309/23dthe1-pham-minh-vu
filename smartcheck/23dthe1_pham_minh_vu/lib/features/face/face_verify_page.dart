import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/theme.dart';
import '../scan/camera_view.dart';
import 'liveness.dart';

/// Mở màn xác thực khuôn mặt. Trả `true` khi người dùng vượt qua thử thách, `false` nếu thoát giữa chừng.
Future<bool> openFaceVerification(BuildContext context) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FaceVerifyPage())) ?? false;

/// Xác thực "người thật" bằng camera trước: đúng một khuôn mặt, rồi chớp mắt hoặc quay đầu (chọn ngẫu nhiên).
/// Toàn bộ chạy trên máy; kết quả chỉ là `faceVerified=true` gửi kèm lúc chấm công.
class FaceVerifyPage extends StatefulWidget {
  const FaceVerifyPage({super.key, this.timeout = const Duration(seconds: 20)});

  /// Hết thời gian này mà chưa xong thì cho thử lại với thử thách mới.
  final Duration timeout;

  @override
  State<FaceVerifyPage> createState() => _FaceVerifyPageState();
}

class _FaceVerifyPageState extends State<FaceVerifyPage> {
  final _detector = FaceDetector(options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast));
  final _handle = CameraHandle();

  late LivenessDetector _liveness = LivenessDetector(LivenessKind.random());
  Timer? _deadline;
  bool _busy = false;
  bool _finished = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _handle.ready.addListener(_onCameraReady);
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _handle.ready.removeListener(_onCameraReady);
    _detector.close();
    _handle.dispose();
    super.dispose();
  }

  void _onCameraReady() {
    if (_handle.ready.value) _armDeadline();
  }

  void _armDeadline() {
    _deadline?.cancel();
    _deadline = Timer(widget.timeout, () {
      if (mounted && !_finished) setState(() => _timedOut = true);
    });
  }

  void _retry() {
    setState(() {
      _liveness = LivenessDetector(LivenessKind.random());
      _timedOut = false;
    });
    _armDeadline();
  }

  Future<void> _onFrame(CameraImage image, CameraDescription camera) async {
    if (_busy || _finished || _timedOut) return;
    _busy = true;
    try {
      final input = toInputImage(image, camera);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _finished) return;
      final f = faces.length == 1 ? faces.first : null;
      final before = _liveness.phase;
      final after = _liveness.update(FaceSample(
        faces: faces.length,
        leftEyeOpen: f?.leftEyeOpenProbability,
        rightEyeOpen: f?.rightEyeOpenProbability,
        yaw: f?.headEulerAngleY,
      ));
      if (after != before) setState(() {});
      if (_liveness.passed) await _succeed();
    } catch (_) {
      // Một khung hình lỗi thì bỏ qua.
    } finally {
      _busy = false;
    }
  }

  Future<void> _succeed() async {
    _finished = true;
    _deadline?.cancel();
    await _handle.stopStream();
    await Future<void>.delayed(const Duration(milliseconds: 700)); // để người dùng thấy dấu tích
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final passed = _liveness.passed;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand, // body của Scaffold có ràng buộc lỏng; không có thì Stack co theo thanh nút trên cùng
        children: [
          CameraView(
            lens: CameraLensDirection.front,
            onFrame: _onFrame,
            handle: _handle,
            rationale: 'SmartCheck dùng camera trước để xác thực bạn là người thật khi chấm công.',
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _handle.ready,
            builder: (_, ready, _) => ready
                ? Stack(fit: StackFit.expand, children: [
                    IgnorePointer(child: SizedBox.expand(child: CustomPaint(painter: _OvalMaskPainter(passed: passed)))),
                    Positioned(left: 24, right: 24, bottom: 48, child: _instruction(passed)),
                  ])
                : const SizedBox.shrink(),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(tooltip: 'Đóng', color: Colors.white, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop(false)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instruction(bool passed) {
    if (_timedOut) {
      return _card(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Chưa xác thực được', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Hãy ở nơi đủ sáng, nhìn thẳng vào camera và làm theo hướng dẫn.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _retry, child: const Text('Thử lại')),
        ]),
      );
    }
    final multiple = _liveness.phase == LivenessPhase.multipleFaces;
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (passed) const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 26)),
          Flexible(
            child: Text(
              _liveness.message,
              key: const Key('liveness-message'),
              textAlign: TextAlign.center,
              style: TextStyle(color: multiple ? AppColors.amber : Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(18)),
        child: child,
      );
}

/// Làm tối ngoài khung oval; viền oval chuyển xanh khi xác thực xong.
class _OvalMaskPainter extends CustomPainter {
  const _OvalMaskPainter({required this.passed});
  final bool passed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.72;
    final oval = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.4), width: w, height: w * 1.32);
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = passed ? AppColors.ok : AppColors.amber,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalMaskPainter old) => old.passed != passed;
}

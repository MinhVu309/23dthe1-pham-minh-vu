import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../core/theme.dart';
import 'camera_view.dart';

/// Mở màn quét và trả về chuỗi QR đọc được (hoặc `null` nếu người dùng thoát).
/// App **không** kiểm tra nội dung: chuỗi được gửi nguyên lên server.
Future<String?> openQrScanner(BuildContext context) => Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  final _handle = CameraHandle();

  bool _busy = false; // đang xử lý một frame → bỏ qua các frame đến sau
  bool _done = false; // đã đọc được mã
  bool _disposed = false;
  bool _torch = false;

  @override
  void dispose() {
    _disposed = true;
    if (!_busy) _scanner.close(); // đang xử lý khung hình thì đóng sau, xem _onFrame
    _handle.dispose();
    super.dispose();
  }

  Future<void> _onFrame(CameraImage image, CameraDescription camera) async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final input = toInputImage(image, camera);
      if (input == null) return;
      final codes = await _scanner.processImage(input);
      final value = codes.map((c) => c.rawValue).whereType<String>().where((v) => v.isNotEmpty).firstOrNull;
      if (value == null || _done || !mounted) return;
      _done = true;
      await _handle.release();
      if (mounted) Navigator.of(context).pop(value);
    } catch (_) {
      // Một frame lỗi thì bỏ qua, frame sau thử lại.
    } finally {
      _busy = false;
      if (_disposed) _scanner.close();
    }
  }

  Future<void> _toggleTorch() async {
    if (await _handle.setTorch(!_torch) && mounted) setState(() => _torch = !_torch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand, // body của Scaffold có ràng buộc lỏng; không có thì Stack co theo thanh nút trên cùng
        children: [
          CameraView(
            lens: CameraLensDirection.back,
            onFrame: _onFrame,
            handle: _handle,
            rationale: 'SmartCheck dùng camera để quét mã QR tại điểm chấm công.',
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _handle.ready,
            builder: (_, ready, _) => ready
                ? Stack(fit: StackFit.expand, children: [
                    const _Viewfinder(),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 48,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                        child: const Text(
                          'Đưa mã QR trên màn hình điểm chấm công vào khung. Mã chỉ có hiệu lực trong ít giây.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, height: 1.4),
                        ),
                      ),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(tooltip: 'Đóng', color: Colors.white, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                    const Spacer(),
                    ValueListenableBuilder<bool>(
                      valueListenable: _handle.ready,
                      builder: (_, ready, _) => ready
                          ? IconButton(
                              tooltip: _torch ? 'Tắt đèn' : 'Bật đèn',
                              color: _torch ? AppColors.amber : Colors.white,
                              icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                              onPressed: _toggleTorch,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung ngắm: làm tối xung quanh, bốn góc màu hổ phách.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) => const IgnorePointer(child: SizedBox.expand(child: CustomPaint(painter: _FramePainter())));
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * 0.68;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.42), width: side, height: side);
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.5));

    final corner = Paint()
      ..color = AppColors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final p = Offset(sx < 0 ? rect.left : rect.right, sy < 0 ? rect.top : rect.bottom);
        canvas.drawLine(p, p + Offset(-sx * len, 0), corner);
        canvas.drawLine(p, p + Offset(0, -sy * len), corner);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

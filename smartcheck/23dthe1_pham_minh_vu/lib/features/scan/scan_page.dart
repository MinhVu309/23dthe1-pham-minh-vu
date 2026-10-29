import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';

/// Mở màn quét và trả về chuỗi QR đọc được (hoặc `null` nếu người dùng thoát).
/// App **không** kiểm tra nội dung: chuỗi được gửi nguyên lên server.
Future<String?> openQrScanner(BuildContext context) => Navigator.of(
  context,
).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));

enum _CamState { checking, denied, deniedForever, starting, ready, failed }

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final _scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  CameraController? _camera;
  _CamState _state = _CamState.checking;
  String? _failure;
  bool _busy = false; // đang xử lý một frame → bỏ qua các frame đến sau
  bool _done = false; // đã đọc được mã
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.close();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Người dùng vừa ra Cài đặt cấp quyền xong thì thử lại.
    if (state == AppLifecycleState.resumed && (_state == _CamState.denied || _state == _CamState.deniedForever)) _start();
  }

  Future<void> _start() async {
    setState(() => _state = _CamState.checking);
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(
        () => _state = status.isPermanentlyDenied
            ? _CamState.deniedForever
            : _CamState.denied,
      );
      return;
    }
    setState(() => _state = _CamState.starting);
    CameraController? controller;
    try {
      // CameraX tự thử lại vô hạn khi máy không có camera phù hợp, nên phải đặt thời hạn.
      await (() async {
        final cameras = await availableCameras();
        final back = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        final desc = back.isNotEmpty ? back.first : cameras.first;
        controller = CameraController(
          desc,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        await controller!.initialize();
        if (!mounted) return;
        await controller!.startImageStream((image) => _onFrame(image, desc));
      })().timeout(const Duration(seconds: 12));
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      _camera = controller;
      setState(() => _state = _CamState.ready);
    } on CameraException catch (e) {
      await controller?.dispose();
      _fail(e.description ?? e.code);
    } on TimeoutException {
      await controller?.dispose();
      _fail(
        'Camera không phản hồi. Hãy đóng các ứng dụng đang dùng camera rồi thử lại.',
      );
    } catch (_) {
      await controller?.dispose();
      _fail('Thiết bị không có camera dùng được.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _state = _CamState.failed;
      _failure = message;
    });
  }

  Future<void> _onFrame(CameraImage image, CameraDescription desc) async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final input = _toInputImage(image, desc);
      if (input == null) return;
      final codes = await _scanner.processImage(input);
      final value = codes
          .map((c) => c.rawValue)
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .firstOrNull;
      if (value == null || _done || !mounted) return;
      _done = true;
      try {
        await _camera?.stopImageStream();
      } catch (_) {}
      if (mounted) Navigator.of(context).pop(value);
    } catch (_) {
      // Một frame lỗi thì bỏ qua, frame sau thử lại.
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription desc) {
    // Màn hình khoá dọc nên chiều xoay của ảnh chính là hướng cảm biến.
    final rotation = InputImageRotationValue.fromRawValue(
      desc.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _toggleTorch() async {
    final c = _camera;
    if (c == null) return;
    try {
      await c.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } on CameraException {
      // Máy không có đèn flash: bỏ qua.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit
            .expand, // body của Scaffold có ràng buộc lỏng; không có thì Stack co theo thanh nút trên cùng
        children: [
          Positioned.fill(child: _body()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Đóng',
                      color: Colors.white,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (_state == _CamState.ready)
                      IconButton(
                        tooltip: _torch ? 'Tắt đèn' : 'Bật đèn',
                        color: _torch ? AppColors.amber : Colors.white,
                        icon: Icon(
                          _torch
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                        ),
                        onPressed: _toggleTorch,
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

  Widget _body() {
    switch (_state) {
      case _CamState.checking:
      case _CamState.starting:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _CamState.denied:
        return _Message(
          icon: Icons.no_photography_outlined,
          title: 'Cần quyền dùng camera',
          body: 'SmartCheck dùng camera để quét mã QR tại điểm chấm công.',
          action: 'Cấp quyền',
          onAction: _start,
        );
      case _CamState.deniedForever:
        return _Message(
          icon: Icons.no_photography_outlined,
          title: 'Camera đang bị chặn',
          body:
              'Hãy bật quyền Camera cho SmartCheck trong Cài đặt, rồi quay lại màn hình này.',
          action: 'Mở Cài đặt',
          onAction: openAppSettings,
        );
      case _CamState.failed:
        return _Message(
          icon: Icons.videocam_off_outlined,
          title: 'Không mở được camera',
          body: _failure ?? 'Thiết bị không có camera dùng được.',
          action: 'Thử lại',
          onAction: _start,
        );
      case _CamState.ready:
        return _preview();
    }
  }

  Widget _preview() {
    final c = _camera!;
    return LayoutBuilder(
      builder: (context, box) {
        final screen = Size(box.maxWidth, box.maxHeight);
        // `aspectRatio` của camera đã tính theo chiều dọc của máy; phóng to cho phủ kín màn hình (kiểu "cover").
        var scale = screen.aspectRatio * c.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;
        return SizedBox.fromSize(
          size: screen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: Transform.scale(
                  scale: scale,
                  child: Center(child: CameraPreview(c)),
                ),
              ),
              const _Viewfinder(),
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Đưa mã QR trên màn hình điểm chấm công vào khung. Mã chỉ có hiệu lực trong ít giây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}

/// Khung ngắm: làm tối xung quanh, bốn góc màu hổ phách.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: SizedBox.expand(child: CustomPaint(painter: _FramePainter())),
  );
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * 0.68;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: side,
      height: side,
    );
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    final corner = Paint()
      ..color = AppColors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final p = Offset(
          sx < 0 ? rect.left : rect.right,
          sy < 0 ? rect.top : rect.bottom,
        );
        canvas.drawLine(p, p + Offset(-sx * len, 0), corner);
        canvas.drawLine(p, p + Offset(0, -sy * len), corner);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

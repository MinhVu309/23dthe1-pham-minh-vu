import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    show InputImage, InputImageFormat, InputImageFormatValue, InputImageMetadata, InputImageRotationValue;
import 'package:permission_handler/permission_handler.dart';

/// Nhận từng khung hình từ camera. Người gọi tự chống chạy chồng (cờ `busy`).
typedef FrameHandler = Future<void> Function(CameraImage image, CameraDescription camera);

/// Cho màn cha điều khiển camera đang chạy trong [CameraView] (dừng luồng ảnh, bật đèn).
class CameraHandle {
  CameraController? _controller;

  /// `true` khi đã có hình xem trước và đang phát khung hình.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  Future<void> stopStream() async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
  }

  /// Dừng luồng ảnh và **đợi đóng hẳn** camera. Phải gọi (và `await`) trước khi mở màn khác cũng dùng
  /// camera: nếu để widget tự dispose thì màn sau mở camera khi màn trước chưa nhả xong → treo hàng chục giây.
  Future<void> release() async {
    final c = _controller;
    _controller = null;
    ready.value = false; // CameraView thôi vẽ hình xem trước
    if (c == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 60)); // chờ một khung hình để bỏ CameraPreview
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  /// Trả `true` nếu đổi được (máy không có đèn flash thì `false`).
  Future<bool> setTorch(bool on) async {
    try {
      await _controller?.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      return true;
    } on CameraException {
      return false;
    }
  }

  void dispose() => ready.dispose();
}

enum _CamState { checking, denied, deniedForever, starting, ready, released, failed }

/// Xin quyền camera, mở camera theo [lens], phủ kín vùng chứa bằng hình xem trước và gọi [onFrame].
/// Chỉ vẽ hình xem trước hoặc thông báo lỗi; nút bấm, khung ngắm... do màn cha xếp chồng lên.
class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.lens, required this.onFrame, required this.handle, required this.rationale});

  final CameraLensDirection lens;
  final FrameHandler onFrame;
  final CameraHandle handle;

  /// Một câu giải thích vì sao cần camera, hiện khi người dùng từ chối quyền.
  final String rationale;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _camera;
  _CamState _state = _CamState.checking;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.handle.ready.addListener(_onHandleChanged);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.handle.ready.removeListener(_onHandleChanged);
    widget.handle._controller = null;
    widget.handle.ready.value = false;
    _camera?.dispose(); // đã dispose qua CameraHandle.release() thì lệnh này không làm gì
    super.dispose();
  }

  /// Màn cha gọi `release()` → bỏ hình xem trước trước khi controller bị đóng.
  void _onHandleChanged() {
    if (!widget.handle.ready.value && _state == _CamState.ready && mounted) setState(() => _state = _CamState.released);
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
      setState(() => _state = status.isPermanentlyDenied ? _CamState.deniedForever : _CamState.denied);
      return;
    }
    setState(() => _state = _CamState.starting);
    CameraController? controller;
    try {
      // CameraX tự thử lại vô hạn khi máy không có camera phù hợp, nên phải đặt thời hạn.
      await (() async {
        final cameras = await availableCameras();
        final wanted = cameras.where((c) => c.lensDirection == widget.lens);
        final desc = wanted.isNotEmpty ? wanted.first : cameras.first;
        controller = CameraController(
          desc,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );
        await controller!.initialize();
        if (!mounted) return;
        await controller!.startImageStream((image) => widget.onFrame(image, desc));
      })().timeout(const Duration(seconds: 12));
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      _camera = controller;
      widget.handle._controller = controller;
      widget.handle.ready.value = true;
      setState(() => _state = _CamState.ready);
    } on CameraException catch (e) {
      await controller?.dispose();
      _fail(e.description ?? e.code);
    } on TimeoutException {
      await controller?.dispose();
      _fail('Camera không phản hồi. Hãy đóng các ứng dụng đang dùng camera rồi thử lại.');
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

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _CamState.checking:
      case _CamState.starting:
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case _CamState.denied:
        return CameraMessage(
          icon: Icons.no_photography_outlined,
          title: 'Cần quyền dùng camera',
          body: widget.rationale,
          action: 'Cấp quyền',
          onAction: _start,
        );
      case _CamState.deniedForever:
        return CameraMessage(
          icon: Icons.no_photography_outlined,
          title: 'Camera đang bị chặn',
          body: 'Hãy bật quyền Camera cho SmartCheck trong Cài đặt, rồi quay lại màn hình này.',
          action: 'Mở Cài đặt',
          onAction: openAppSettings,
        );
      case _CamState.failed:
        return CameraMessage(
          icon: Icons.videocam_off_outlined,
          title: 'Không mở được camera',
          body: _failure ?? 'Thiết bị không có camera dùng được.',
          action: 'Thử lại',
          onAction: _start,
        );
      case _CamState.ready:
        return _preview(_camera!);
      case _CamState.released:
        return const SizedBox.shrink();
    }
  }

  Widget _preview(CameraController c) => LayoutBuilder(builder: (context, box) {
        final screen = Size(box.maxWidth, box.maxHeight);
        // `aspectRatio` của camera đã tính theo chiều dọc của máy; phóng to cho phủ kín (kiểu "cover").
        var scale = screen.aspectRatio * c.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;
        return SizedBox.fromSize(
          size: screen,
          child: ClipRect(child: Transform.scale(scale: scale, child: Center(child: CameraPreview(c)))),
        );
      });
}

class CameraMessage extends StatelessWidget {
  const CameraMessage({super.key, required this.icon, required this.title, required this.body, required this.action, required this.onAction});

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
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ),
        ),
      );
}

/// Đổi khung hình camera sang ảnh cho ML Kit. Màn hình khoá dọc nên chiều xoay của ảnh là hướng cảm biến.
InputImage? toInputImage(CameraImage image, CameraDescription camera) {
  final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
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

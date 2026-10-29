import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../services/device_id.dart';
import '../../services/location_service.dart';
import '../shared/common.dart';
import '../face/face_verify_page.dart';
import 'check_failure.dart';
import 'scan_page.dart';

final _timeFmt = DateFormat('HH:mm:ss dd/MM/yyyy');

/// Vị trí đọc quá lâu thì đọc lại trước khi gửi (QR chỉ sống ~45 s nhưng người dùng có thể đã đi chỗ khác).
const _maxReadingAge = Duration(seconds: 30);

/// Chấm công vào/ra: lấy GPS → xác thực khuôn mặt → quét QR → gửi lên server → hiện kết quả.
///
/// Khuôn mặt làm trước khi quét QR vì QR chỉ sống ~45 s. App chỉ thu thập: server mới quyết định
/// QR, phạm vi, GPS giả; `faceVerified` chỉ cho biết đã vượt qua thử thách chớp mắt/quay đầu.
class CheckPage extends StatefulWidget {
  const CheckPage({super.key, this.scan = openQrScanner, this.verifyFace = openFaceVerification});

  /// Mở màn quét QR; test thay bằng hàm trả chuỗi cố định.
  final Future<String?> Function(BuildContext context) scan;

  /// Mở màn xác thực khuôn mặt; `true` khi vượt qua. Test thay bằng hàm trả sẵn kết quả.
  final Future<bool> Function(BuildContext context) verifyFace;

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  AttendanceType _type = AttendanceType.checkIn;

  LocationReading? _reading;
  LocationException? _problem;
  bool _locating = false;

  bool _submitting = false;
  CheckResult? _result;
  CheckFailure? _failure;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// Đọc GPS và cập nhật thẻ vị trí. Trả `null` nếu không lấy được (lý do nằm ở [_problem]).
  Future<LocationReading?> _locate() async {
    final provider = context.read<LocationProvider>();
    setState(() {
      _locating = true;
      _problem = null;
    });
    try {
      final r = await provider.read();
      if (mounted) setState(() => _reading = r);
      return r;
    } on LocationException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e;
          _reading = null;
        });
      }
      return null;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _scanAndSubmit() async {
    final repo = context.read<AttendanceRepository>();
    final devices = context.read<DeviceIdProvider>();

    var reading = _reading;
    if (reading == null || nowProvider().difference(reading.takenAt) > _maxReadingAge) reading = await _locate();
    if (reading == null || !mounted) return;

    final faceOk = await widget.verifyFace(context);
    if (!faceOk || !mounted) return;

    final qr = await widget.scan(context);
    if (qr == null || !mounted) return;

    setState(() {
      _submitting = true;
      _result = null;
      _failure = null;
    });
    try {
      final deviceId = await devices.get();
      final result = await repo.check(
        _type,
        CheckPayload(
          qrToken: qr,
          latitude: reading.latitude,
          longitude: reading.longitude,
          accuracy: reading.accuracy,
          isMocked: reading.isMocked,
          deviceId: deviceId,
          faceVerified: faceOk,
        ),
      );
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _failure = CheckFailure.from(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _locating;
    return Scaffold(
      appBar: AppBar(title: const Text('Chấm công', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedButton<AttendanceType>(
            showSelectedIcon: false,
            segments: [
              for (final t in AttendanceType.values) ButtonSegment(value: t, label: Text(t.label), icon: Icon(t == AttendanceType.checkIn ? Icons.login_rounded : Icons.logout_rounded)),
            ],
            selected: {_type},
            onSelectionChanged: _submitting ? null : (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 18),
          _positionCard(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : _scanAndSubmit,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.qr_code_scanner_rounded),
            label: Text(_submitting ? 'Đang gửi...' : 'Quét mã QR để ${_type.label.toLowerCase()}'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Các bước: xác định vị trí → xác thực khuôn mặt (chớp mắt hoặc quay đầu) → quét mã QR.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35)),
          ),
          const SizedBox(height: 18),
          if (_result != null) _ResultCard(_result!),
          if (_failure != null) _FailureCard(_failure!),
        ],
      ),
    );
  }

  Widget _positionCard() {
    final r = _reading;
    final p = _problem;
    Widget body;
    if (_locating && r == null) {
      body = const Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
        SizedBox(width: 12),
        Text('Đang xác định vị trí...'),
      ]);
    } else if (p != null) {
      body = Column(
        key: const Key('location-problem'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.message, style: const TextStyle(color: AppColors.danger, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: _locating ? null : _locate, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
            if (p.needsSettings)
              OutlinedButton.icon(
                onPressed: () => context.read<LocationProvider>().openSettings(p.problem),
                icon: const Icon(Icons.settings_outlined),
                label: Text(p.settingsLabel),
              ),
          ]),
        ],
      );
    } else if (r != null) {
      final weak = r.accuracy > _weakAccuracy;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}',
                  key: const Key('location-coords'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
            ),
            IconButton(tooltip: 'Cập nhật vị trí', onPressed: _locating ? null : _locate, icon: const Icon(Icons.refresh_rounded)),
          ]),
          Text('Sai số khoảng ${r.accuracy.round()} m', style: TextStyle(color: weak ? AppColors.amberDark : AppColors.textMuted)),
          if (weak)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('GPS đang yếu, hệ thống có thể từ chối. Hãy ra nơi thoáng hơn rồi cập nhật lại.', style: TextStyle(color: AppColors.amberDark, fontSize: 13, height: 1.35)),
            ),
          if (r.isMocked)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Thiết bị đang báo vị trí giả lập. Chấm công sẽ bị từ chối và quản lý nhận được cảnh báo.',
                  key: Key('location-mocked'), style: TextStyle(color: AppColors.danger, fontSize: 13, height: 1.35)),
            ),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.paperDeep)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.my_location_rounded, color: AppColors.inkSoft),
            SizedBox(width: 10),
            Text('Vị trí của bạn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
          ]),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

/// Server từ chối khi sai số lớn hơn mức này (`Fraud:MaxAccuracyMeters`, mặc định 100 m); chỉ để báo trước.
const _weakAccuracy = 100;

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.r);
  final CheckResult r;

  @override
  Widget build(BuildContext context) {
    final onTime = r.type == AttendanceType.checkIn ? !r.isLate : !r.isEarlyLeave;
    final status = r.isLate
        ? 'Đi trễ'
        : r.isEarlyLeave
            ? 'Về sớm'
            : 'Đúng giờ';
    return Container(
      key: const Key('check-success'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.ok.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.ok.withValues(alpha: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text('Chấm công ${r.type.label.toLowerCase()} thành công', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink))),
          ]),
          const SizedBox(height: 12),
          _line(Icons.schedule_rounded, _timeFmt.format(r.time)),
          _line(Icons.social_distance_rounded, 'Cách điểm chấm công ${r.distance.round()} m'),
          const SizedBox(height: 8),
          StatusChip(status, onTime ? AppColors.ok : AppColors.amberDark),
          for (final f in r.flags) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.flag_outlined, size: 18, color: AppColors.amberDark),
              const SizedBox(width: 6),
              Expanded(child: Text(f, style: const TextStyle(color: AppColors.amberDark))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Icon(icon, size: 18, color: AppColors.inkSoft), const SizedBox(width: 8), Text(text)]),
      );
}

class _FailureCard extends StatelessWidget {
  const _FailureCard(this.f);
  final CheckFailure f;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('check-failure'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.danger.withValues(alpha: 0.35))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.error_rounded, color: AppColors.danger, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.danger))),
            ]),
            const SizedBox(height: 8),
            Text(f.message, style: const TextStyle(height: 1.4)),
            for (final r in f.reasons) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: AppColors.danger)),
                Expanded(child: Text(r)),
              ]),
            ],
            if (f.retryable) ...[
              const SizedBox(height: 10),
              const Text('Bạn có thể quét lại.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ],
        ),
      );
}

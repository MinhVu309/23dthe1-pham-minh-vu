import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/attendance.dart';
import '../../data/models/work_location.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../services/device_id.dart';
import '../../services/location_service.dart';
import '../face/face_verify_page.dart';
import '../shared/common.dart';
import 'check_failure.dart';
import 'scan_page.dart';

final _timeFmt = DateFormat('HH:mm:ss dd/MM/yyyy');

/// Nghỉ giữa lúc đóng camera trước (khuôn mặt) và mở camera sau (QR).
const _cameraSwitchGap = Duration(milliseconds: 400);

/// Vị trí đọc quá lâu thì đọc lại trước khi gửi (QR chỉ sống ~45 s nhưng người dùng có thể đã đi chỗ khác).
const _maxReadingAge = Duration(seconds: 30);

/// Chấm công vào/ra: lấy GPS → xác thực khuôn mặt → quét QR → gửi lên server → hiện kết quả.
///
/// Bố cục: chip Vào/Ra ca, banner, bản đồ vị trí, đường thời gian ba bước cùng thẻ khoảng cách lớn,
/// thanh nút dưới đáy. Khuôn mặt làm trước khi quét QR vì QR chỉ sống ~45 s. App chỉ thu thập: server mới quyết
/// định QR, phạm vi, GPS giả.
class CheckPage extends StatefulWidget {
  const CheckPage({
    super.key,
    this.scan = openQrScanner,
    this.verifyFace = openFaceVerification,
  });

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
  List<WorkLocation> _locations = const [];

  bool _bannerClosed = false;
  bool _faceDone = false;
  bool _qrDone = false;

  bool _submitting = false;
  CheckResult? _result;
  CheckFailure? _failure;
  final _outcomeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _locate();
    _loadLocations();
  }

  /// Danh sách địa điểm chỉ để vẽ bản đồ và ước tính khoảng cách; không có thì vẫn chấm công được.
  Future<void> _loadLocations() async {
    try {
      final list = (await context.read<LocationRepository>().list()).items;
      if (mounted) setState(() => _locations = list);
    } on ApiException {
      // bỏ qua
    }
  }

  /// Địa điểm gần nhất với vị trí hiện tại (ước tính ở phía app).
  (WorkLocation, double)? get _nearest {
    final r = _reading;
    if (r == null || _locations.isEmpty) return null;
    WorkLocation? best;
    var bestD = double.infinity;
    for (final l in _locations) {
      final d = distanceMeters(
        r.latitude,
        r.longitude,
        l.latitude,
        l.longitude,
      );
      if (d < bestD) {
        bestD = d;
        best = l;
      }
    }
    return (best!, bestD);
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

    setState(() {
      _faceDone = false;
      _qrDone = false;
    });

    var reading = _reading;
    if (reading == null || nowProvider().difference(reading.takenAt) > _maxReadingAge) reading = await _locate();
    if (reading == null || !mounted) return;

    final faceOk = await widget.verifyFace(context);
    if (!faceOk || !mounted) return;
    setState(() => _faceDone = true);
    // Để phần cứng camera nhả hẳn camera trước rồi mới mở camera sau.
    await Future<void>.delayed(_cameraSwitchGap);
    if (!mounted) return;

    final qr = await widget.scan(context);
    if (qr == null || !mounted) return;
    setState(() => _qrDone = true);

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
    _scrollToOutcome();
  }

  /// Màn dài hơn một màn hình: cuộn tới thẻ kết quả/lỗi để người dùng thấy ngay sau khi quét.
  void _scrollToOutcome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _outcomeKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _locating;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Chấm công',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilterChips<AttendanceType>(
                    options: AttendanceType.values,
                    selected: _type,
                    labelOf: (t) => t.label,
                    padding: 0,
                    onChanged: (t) {
                      if (!_submitting) setState(() => _type = t);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (!_bannerClosed) ...[
                    _banner(),
                    const SizedBox(height: 16),
                  ],
                  if (_problem != null) ...[
                    _problemCard(_problem!),
                    const SizedBox(height: 14),
                  ],
                  _mapCard(),
                  const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 11, child: _timeline()),
                        const SizedBox(width: 12),
                        Expanded(flex: 10, child: _distanceCard()),
                      ],
                    ),
                  ),
                  ..._warnings(),
                  if (_result != null) ...[
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: _outcomeKey,
                      child: _ResultCard(_result!),
                    ),
                  ],
                  if (_failure != null) ...[
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: _outcomeKey,
                      child: _FailureCard(_failure!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _bottomBar(busy),
        ],
      ),
    );
  }

  Widget _banner() => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
    decoration: BoxDecoration(
      gradient: AppColors.brandGradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppColors.brand.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_user_rounded, color: Colors.white, size: 38),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đúng người, đúng chỗ, đúng giờ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Mỗi lần gồm 3 bước: vị trí, khuôn mặt, mã QR. QR đổi mỗi 30 giây nên hãy quét ngay.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Ẩn',
          onPressed: () => setState(() => _bannerClosed = true),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _mapCard() {
    final r = _reading;
    final near = _nearest;
    Widget inner;
    if (r == null && _locations.isEmpty) {
      inner = Container(
        color: AppColors.paper,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _locating
                  ? Icons.gps_not_fixed_rounded
                  : Icons.location_off_outlined,
              size: 34,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              _locating ? 'Đang xác định vị trí...' : 'Chưa có vị trí',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    } else {
      final points = <LatLng>[
        if (r != null) LatLng(r.latitude, r.longitude),
        if (near != null) LatLng(near.$1.latitude, near.$1.longitude),
      ];
      final center = points.isNotEmpty
          ? points.first
          : LatLng(_locations.first.latitude, _locations.first.longitude);
      inner = FlutterMap(
        key: ValueKey('${r?.latitude}/${r?.longitude}/${_locations.length}'),
        options: MapOptions(
          initialCenter: center,
          initialZoom: 16,
          initialCameraFit: points.length > 1
              ? CameraFit.coordinates(
                  coordinates: points,
                  padding: const EdgeInsets.all(44),
                  maxZoom: 17,
                )
              : null,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.phamminhvu.chamcong',
          ),
          CircleLayer(
            circles: [
              for (final l in _locations)
                CircleMarker(
                  point: LatLng(l.latitude, l.longitude),
                  radius: l.radiusMeters.toDouble(),
                  useRadiusInMeter: true,
                  color: AppColors.amber.withValues(alpha: 0.22),
                  borderColor: AppColors.amber,
                  borderStrokeWidth: 2,
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              for (final l in _locations)
                Marker(
                  point: LatLng(l.latitude, l.longitude),
                  width: 34,
                  height: 34,
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: AppColors.amberDark,
                    size: 26,
                  ),
                ),
              if (r != null)
                Marker(
                  point: LatLng(r.latitude, r.longitude),
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sky.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.paperDeep),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _problemCard(LocationException p) => Container(
    key: const Key('location-problem'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.message,
          style: const TextStyle(color: AppColors.danger, height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
            if (p.needsSettings)
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<LocationProvider>().openSettings(p.problem),
                icon: const Icon(Icons.settings_outlined),
                label: Text(p.settingsLabel),
              ),
          ],
        ),
      ],
    ),
  );

  /// Đường thời gian ba bước: vị trí → khuôn mặt → mã QR.
  Widget _timeline() {
    final r = _reading;
    final steps = [
      (
        'Vị trí',
        _problem != null
            ? 'Chưa lấy được'
            : (r != null
                  ? '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}'
                  : 'Đang xác định...'),
        r != null,
        AppColors.sky,
      ),
      ('Khuôn mặt', 'Chớp mắt hoặc quay đầu', _faceDone, AppColors.brand),
      ('Mã QR', 'Quét tại điểm chấm công', _qrDone, AppColors.amber),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: steps[i].$3 ? steps[i].$4 : Colors.white,
                  border: Border.all(
                    color: steps[i].$4,
                    width: steps[i].$3 ? 0 : 3,
                  ),
                ),
                child: steps[i].$3
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      steps[i].$2,
                      key: i == 0 && r != null
                          ? const Key('location-coords')
                          : null,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
              child: Column(
                children: List.generate(
                  4,
                  (_) => Container(
                    width: 2,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    color: AppColors.paperDeep,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Thẻ số lớn: khoảng cách ước tính tới điểm chấm công gần nhất.
  Widget _distanceCard() {
    final r = _reading;
    final near = _nearest;
    var value = '--';
    var unit = 'mét';
    if (near != null) {
      final d = near.$2;
      if (d >= 1000) {
        value = (d / 1000).toStringAsFixed(1);
        unit = 'km';
      } else {
        value = '${d.round()}';
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.paperDeep),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            key: const Key('distance-value'),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 16, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          Text(
            near != null
                ? 'Cách ${near.$1.name}'
                : 'Khoảng cách tới điểm chấm công',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
          if (near != null)
            Text(
              'Cho phép ${near.$1.radiusMeters} m',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          if (r != null) ...[
            const SizedBox(height: 6),
            Text(
              'Sai số khoảng ${r.accuracy.round()} m',
              style: TextStyle(
                color: r.accuracy > _weakAccuracy
                    ? AppColors.amberDark
                    : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _warnings() {
    final r = _reading;
    if (r == null) return const [];
    return [
      if (r.accuracy > _weakAccuracy)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'GPS đang yếu, hệ thống có thể từ chối. Hãy ra nơi thoáng hơn rồi cập nhật lại.',
            style: TextStyle(
              color: AppColors.amberDark,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      if (r.isMocked)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Thiết bị đang báo vị trí giả lập. Chấm công sẽ bị từ chối và quản lý nhận được cảnh báo.',
            key: Key('location-mocked'),
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
    ];
  }

  Widget _bottomBar(bool busy) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: Row(
      children: [
        SquareIconButton(
          icon: Icons.my_location_rounded,
          color: AppColors.sky,
          tooltip: 'Cập nhật vị trí',
          onPressed: _locating || _submitting ? null : _locate,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GradientButton(
            label: _submitting
                ? 'Đang gửi...'
                : 'Quét mã QR để ${_type.label.toLowerCase()}',
            icon: Icons.qr_code_scanner_rounded,
            busy: busy,
            onPressed: busy ? null : _scanAndSubmit,
          ),
        ),
      ],
    ),
  );
}

/// Server từ chối khi sai số lớn hơn mức này (`Fraud:MaxAccuracyMeters`, mặc định 100 m); chỉ để báo trước.
const _weakAccuracy = 100;

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.r);
  final CheckResult r;

  @override
  Widget build(BuildContext context) {
    final onTime = r.type == AttendanceType.checkIn
        ? !r.isLate
        : !r.isEarlyLeave;
    final status = r.isLate
        ? 'Đi trễ'
        : r.isEarlyLeave
        ? 'Về sớm'
        : 'Đúng giờ';
    return Container(
      key: const Key('check-success'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ok.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ok.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.ok,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chấm công ${r.type.label.toLowerCase()} thành công',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _line(Icons.schedule_rounded, _timeFmt.format(r.time)),
          _line(
            Icons.social_distance_rounded,
            'Cách điểm chấm công ${r.distance.round()} m',
          ),
          const SizedBox(height: 8),
          StatusChip(status, onTime ? AppColors.ok : AppColors.amberDark),
          for (final f in r.flags) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppColors.amberDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(color: AppColors.amberDark),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkSoft),
        const SizedBox(width: 8),
        Text(text),
      ],
    ),
  );
}

class _FailureCard extends StatelessWidget {
  const _FailureCard(this.f);
  final CheckFailure f;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('check-failure'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_rounded, color: AppColors.danger, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                f.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(f.message, style: const TextStyle(height: 1.4)),
        for (final r in f.reasons) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(color: AppColors.danger)),
              Expanded(child: Text(r)),
            ],
          ),
        ],
        if (f.retryable) ...[
          const SizedBox(height: 10),
          const Text(
            'Bạn có thể quét lại.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

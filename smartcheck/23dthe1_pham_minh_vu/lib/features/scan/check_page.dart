import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models/attendance.dart';
import '../../data/models/work_location.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../services/device_id.dart';
import '../shared/common.dart';
import 'check_failure.dart';
import 'scan_page.dart';

final _timeFmt = DateFormat('HH:mm:ss dd/MM/yyyy');

/// Chấm công vào/ra: nhập vị trí → quét QR → gửi lên server → hiện kết quả.
///
/// Vị trí đang nhập tay (tạm thời), `isMocked=false` và `faceVerified=true` là giá trị tạm;
/// các giai đoạn D (GPS thật, chống fake GPS) và E (khuôn mặt) sẽ thay thế.
class CheckPage extends StatefulWidget {
  const CheckPage({super.key, this.scan = openQrScanner});

  /// Mở màn quét QR; test thay bằng hàm trả chuỗi cố định.
  final Future<String?> Function(BuildContext context) scan;

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  final _formKey = GlobalKey<FormState>();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _accuracy = TextEditingController(text: '10');

  AttendanceType _type = AttendanceType.checkIn;
  List<WorkLocation> _locations = const [];
  bool _submitting = false;
  CheckResult? _result;
  CheckFailure? _failure;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _accuracy.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final list = (await context.read<LocationRepository>().list()).items;
      if (mounted) setState(() => _locations = list);
    } on ApiException {
      // Chỉ để gợi ý toạ độ; không có thì người dùng vẫn nhập tay được.
    }
  }

  void _useLocation(WorkLocation l) {
    setState(() {
      _lat.text = l.latitude.toString();
      _lng.text = l.longitude.toString();
    });
  }

  static double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  String? _coord(String? v, double min, double max, String label) {
    final n = _num(v ?? '');
    if (n == null) return 'Nhập $label';
    if (n < min || n > max) return '$label phải từ $min đến $max';
    return null;
  }

  Future<void> _scanAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = _num(_lat.text)!, lng = _num(_lng.text)!, acc = _num(_accuracy.text)!;
    final repo = context.read<AttendanceRepository>();
    final devices = context.read<DeviceIdProvider>();

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
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          isMocked: false,
          deviceId: deviceId,
          faceVerified: true,
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
            onPressed: _submitting ? null : _scanAndSubmit,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.qr_code_scanner_rounded),
            label: Text(_submitting ? 'Đang gửi...' : 'Quét mã QR để ${_type.label.toLowerCase()}'),
          ),
          const SizedBox(height: 18),
          if (_result != null) _ResultCard(_result!),
          if (_failure != null) _FailureCard(_failure!),
        ],
      ),
    );
  }

  Widget _positionCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.paperDeep)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.my_location_rounded, color: AppColors.inkSoft),
                SizedBox(width: 10),
                Text('Vị trí của bạn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
              ]),
              const SizedBox(height: 4),
              const Text('Tạm thời nhập tay. Giai đoạn sau app sẽ lấy từ GPS.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              if (_locations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<WorkLocation>(
                    key: const Key('pick-location'),
                    decoration: const InputDecoration(labelText: 'Lấy toạ độ từ địa điểm'),
                    items: [for (final l in _locations) DropdownMenuItem(value: l, child: Text(l.name, overflow: TextOverflow.ellipsis))],
                    onChanged: (l) => l == null ? null : _useLocation(l),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      decoration: const InputDecoration(labelText: 'Vĩ độ'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) => _coord(v, -90, 90, 'vĩ độ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lng,
                      decoration: const InputDecoration(labelText: 'Kinh độ'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) => _coord(v, -180, 180, 'kinh độ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accuracy,
                decoration: const InputDecoration(labelText: 'Độ chính xác (m)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _num(v ?? '');
                  return n == null || n <= 0 ? 'Nhập số lớn hơn 0' : null;
                },
              ),
            ],
          ),
        ),
      );
}

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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/models/attendance.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/work_location.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../shared/common.dart';

enum _Range {
  today('Hôm nay', 0),
  week('7 ngày', 6),
  month('30 ngày', 29);

  const _Range(this.label, this.daysBack);
  final String label;
  final int daysBack;

  DateTime from() {
    final n = nowProvider();
    return DateTime(n.year, n.month, n.day).subtract(Duration(days: daysBack));
  }
}

final _timeFmt = DateFormat('HH:mm dd/MM/yyyy');

/// Bản đồ OpenStreetMap: vòng tròn là vùng cho phép của từng địa điểm, chấm là lượt chấm công của nhân viên.
class AttendanceMapPage extends StatefulWidget {
  const AttendanceMapPage({super.key});

  @override
  State<AttendanceMapPage> createState() => _AttendanceMapPageState();
}

class _AttendanceMapPageState extends State<AttendanceMapPage> {
  _Range _range = _Range.today;
  List<WorkLocation> _locations = const [];
  AttendanceList? _data;
  String? _error;
  bool _loading = true;
  int _version = 0; // đổi sau mỗi lần tải để dựng lại bản đồ với khung nhìn mới

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final attendance = context.read<AttendanceRepository>();
    final locations = context.read<LocationRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locationsFuture = locations.list();
      final dataFuture = attendance.list(from: _range.from());
      await Future.wait([locationsFuture, dataFuture]); // ném lại lỗi gốc (ApiException) của lời gọi hỏng đầu tiên
      final locs = await locationsFuture;
      final data = await dataFuture;
      if (!mounted) return;
      setState(() {
        _locations = locs.items;
        _data = data;
        _version++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetail(AttendanceRecord r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.userName.isEmpty ? 'Không rõ' : r.userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('${r.type.label} · ${_timeFmt.format(r.time)}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Text('Địa điểm: ${r.location}'),
            Text('Cách điểm chấm công ${r.distance.round()} m'),
            Text('Toạ độ: ${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}'),
            const SizedBox(height: 10),
            StatusChip(
              r.isLate ? 'Đi trễ' : (r.isEarlyLeave ? 'Về sớm' : 'Đúng giờ'),
              r.isOnTime ? AppColors.ok : AppColors.amberDark,
            ),
          ],
        ),
      ),
    );
  }

  Color _colorOf(AttendanceRecord r) => !r.isOnTime ? AppColors.amberDark : (r.type == AttendanceType.checkIn ? AppColors.ok : AppColors.inkSoft);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ chấm công', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Tải lại', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          FilterChips<_Range>(
            options: _Range.values,
            selected: _range,
            labelOf: (r) => r.label,
            onChanged: (r) {
              if (r == _range) return;
              setState(() => _range = r);
              _load();
            },
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) return const LoadingView();
    if (_error != null && _data == null) return ErrorView(message: _error!, onRetry: _load);
    final data = _data!;
    final points = <LatLng>[
      for (final l in _locations) LatLng(l.latitude, l.longitude),
      for (final r in data.items) LatLng(r.latitude, r.longitude),
    ];

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(_version),
          options: MapOptions(
            initialCenter: points.isEmpty ? const LatLng(10.8019, 106.7144) : points.first,
            initialZoom: 15,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(56), maxZoom: 17)
                : null,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.phamminhvu.chamcong'),
            CircleLayer(circles: [
              for (final l in _locations)
                CircleMarker(
                  point: LatLng(l.latitude, l.longitude),
                  radius: l.radiusMeters.toDouble(),
                  useRadiusInMeter: true,
                  color: AppColors.amber.withValues(alpha: 0.22),
                  borderColor: AppColors.amber,
                  borderStrokeWidth: 2,
                ),
            ]),
            MarkerLayer(markers: [
              for (final l in _locations)
                Marker(
                  point: LatLng(l.latitude, l.longitude),
                  width: 120,
                  height: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
                        child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                      const Icon(Icons.apartment_rounded, size: 22, color: AppColors.ink),
                    ],
                  ),
                ),
              for (final r in data.items)
                Marker(
                  point: LatLng(r.latitude, r.longitude),
                  width: 30,
                  height: 30,
                  child: GestureDetector(
                    key: Key('att-${r.id}'),
                    onTap: () => _showDetail(r),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _colorOf(r),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4)],
                      ),
                      child: Icon(r.type == AttendanceType.checkIn ? Icons.login_rounded : Icons.logout_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ),
            ]),
            const SimpleAttributionWidget(source: Text('© OpenStreetMap')),
          ],
        ),
        if (_loading) const Positioned(top: 8, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
        Positioned(left: 12, right: 12, bottom: 16, child: _Legend(shown: data.items.length, total: data.total)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.shown, required this.total});
  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == 0
                ? 'Chưa có lượt chấm công trong khoảng này'
                : (shown < total ? 'Hiển thị $shown/$total lượt gần nhất' : '$total lượt chấm công'),
            key: const Key('map-summary'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 4, children: [dot(AppColors.ok, 'Vào đúng giờ'), dot(AppColors.inkSoft, 'Ra ca'), dot(AppColors.amberDark, 'Trễ / về sớm')]),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/shift.dart';
import '../../data/models/work_location.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../shared/common.dart';
import '../shared/resource_list_page.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  List<Shift> _shifts = const [];

  Future<List<WorkLocation>> _load() async {
    final locations = context.read<LocationRepository>();
    final shifts = context.read<ShiftRepository>();
    final results = await Future.wait([locations.list(), shifts.list()]);
    _shifts = results[1].items as List<Shift>;
    return results[0].items as List<WorkLocation>;
  }

  Future<bool> _open(BuildContext ctx, {WorkLocation? existing}) async {
    if (_shifts.isEmpty) {
      showSnack(ctx, 'Hãy tạo ít nhất một ca làm việc trước.');
      return false;
    }
    final saved = await Navigator.of(ctx).push<bool>(
      MaterialPageRoute(builder: (_) => LocationFormPage(existing: existing, shifts: _shifts)),
    );
    return saved == true;
  }

  Future<void> _delete(BuildContext context, WorkLocation l, Future<void> Function() reload) async {
    final repo = context.read<LocationRepository>();
    final ok = await confirmDialog(context, title: 'Xoá địa điểm?', message: 'Địa điểm "${l.name}" sẽ bị xoá.');
    if (!ok || !context.mounted) return;
    if (await guard(context, () => repo.delete(l.id), success: 'Đã xoá địa điểm')) await reload();
  }

  String _shiftName(int id) => _shifts.where((s) => s.id == id).map((s) => s.name).firstOrNull ?? 'Ca #$id';

  @override
  Widget build(BuildContext context) {
    return ResourceListPage<WorkLocation>(
      title: 'Địa điểm chấm công',
      load: _load,
      emptyIcon: Icons.place_outlined,
      emptyTitle: 'Chưa có địa điểm',
      emptySubtitle: 'Địa điểm cho biết nhân viên được chấm công ở đâu.',
      addLabel: 'Thêm địa điểm',
      onAdd: (ctx) => _open(ctx),
      itemBuilder: (ctx, l, reload) => ItemCard(
        leading: const IconBadge(Icons.place_outlined),
        title: l.name,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (l.address != null && l.address!.isNotEmpty) Text(l.address!, style: const TextStyle(color: AppColors.textMuted)),
            Text('Bán kính ${l.radiusMeters} m · ${_shiftName(l.shiftId)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Text('${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Xoá',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          onPressed: () => _delete(ctx, l, reload),
        ),
        onTap: () async {
          if (await _open(ctx, existing: l)) await reload();
        },
      ),
    );
  }
}

const _defaultCenter = LatLng(10.8019, 106.7144); // TP.HCM, chỉ là điểm bắt đầu khi tạo mới

class LocationFormPage extends StatefulWidget {
  const LocationFormPage({super.key, this.existing, required this.shifts});

  final WorkLocation? existing;
  final List<Shift> shifts;

  @override
  State<LocationFormPage> createState() => _LocationFormPageState();
}

class _LocationFormPageState extends State<LocationFormPage> {
  final _form = GlobalKey<FormState>();
  final _map = MapController();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _lat = TextEditingController();
  late final _lng = TextEditingController();
  late LatLng _point;
  late double _radius;
  int? _shiftId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _point = e == null ? _defaultCenter : LatLng(e.latitude, e.longitude);
    _radius = (e?.radiusMeters ?? 100).toDouble().clamp(20, 1000);
    _shiftId = e?.shiftId ?? widget.shifts.first.id;
    if (!widget.shifts.any((s) => s.id == _shiftId)) _shiftId = widget.shifts.first.id;
    _lat.text = _point.latitude.toStringAsFixed(6);
    _lng.text = _point.longitude.toStringAsFixed(6);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    _map.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  void _onTapMap(LatLng p) {
    setState(() {
      _point = p;
      _lat.text = p.latitude.toStringAsFixed(6);
      _lng.text = p.longitude.toStringAsFixed(6);
    });
  }

  /// Gõ toạ độ bằng tay thì di chuyển ghim trên bản đồ theo.
  void _onCoordTyped() {
    final la = _parse(_lat.text), lo = _parse(_lng.text);
    if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) return;
    setState(() => _point = LatLng(la, lo));
    _map.move(_point, _map.camera.zoom);
  }

  String? _validateCoord(String? v, double limit, String label) {
    final n = _parse(v ?? '');
    if (n == null) return 'Nhập $label';
    if (n.abs() > limit) return '$label trong khoảng ±${limit.toInt()}';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<LocationRepository>();
    final nav = Navigator.of(context);
    final address = _address.text.trim().isEmpty ? null : _address.text.trim();
    final lat = _parse(_lat.text)!, lng = _parse(_lng.text)!;
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      final e = widget.existing;
      if (e == null) {
        await repo.create(name: _name.text.trim(), address: address, latitude: lat, longitude: lng, radiusMeters: _radius.round(), shiftId: _shiftId!);
      } else {
        await repo.update(e.id, name: _name.text.trim(), address: address, latitude: lat, longitude: lng, radiusMeters: _radius.round(), shiftId: _shiftId!);
      }
    }, success: widget.existing == null ? 'Đã thêm địa điểm' : 'Đã lưu thay đổi');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Thêm địa điểm' : 'Sửa địa điểm', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Tên địa điểm', prefixIcon: Icon(Icons.business_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên địa điểm' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Địa chỉ (không bắt buộc)', prefixIcon: Icon(Icons.signpost_outlined)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _shiftId,
              decoration: const InputDecoration(labelText: 'Ca làm việc', prefixIcon: Icon(Icons.schedule_outlined)),
              items: [for (final s in widget.shifts) DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.range})'))],
              onChanged: (v) => setState(() => _shiftId = v),
              validator: (v) => v == null ? 'Chọn ca làm việc' : null,
            ),
            const SizedBox(height: 20),
            const Text('Vị trí trên bản đồ', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Chạm vào bản đồ để đặt ghim. Vòng tròn là vùng cho phép chấm công.', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 300,
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _point,
                    initialZoom: 16,
                    onTap: (_, p) => _onTapMap(p),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.phamminhvu.chamcong'),
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _point,
                        radius: _radius,
                        useRadiusInMeter: true,
                        color: AppColors.amber.withValues(alpha: 0.28),
                        borderColor: AppColors.amber,
                        borderStrokeWidth: 2,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: _point,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 44),
                      ),
                    ]),
                    const SimpleAttributionWidget(source: Text('© OpenStreetMap')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Vĩ độ'),
                    onChanged: (_) => _onCoordTyped(),
                    validator: (v) => _validateCoord(v, 90, 'vĩ độ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Kinh độ'),
                    onChanged: (_) => _onCoordTyped(),
                    validator: (v) => _validateCoord(v, 180, 'kinh độ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Bán kính', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                const Spacer(),
                Text('${_radius.round()} m', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 16)),
              ],
            ),
            Slider(
              value: _radius,
              min: 20,
              max: 1000,
              divisions: 98,
              activeColor: AppColors.ink,
              label: '${_radius.round()} m',
              onChanged: (v) => setState(() => _radius = v),
            ),
            const Text('Nên từ 50 m trở lên vì GPS điện thoại thường sai số vài chục mét.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 24),
            BusyButton(label: 'Lưu địa điểm', busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

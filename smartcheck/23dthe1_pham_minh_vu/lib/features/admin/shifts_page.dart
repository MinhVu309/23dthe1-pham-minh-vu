import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/shift.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../shared/common.dart';
import '../shared/resource_list_page.dart';

class ShiftsPage extends StatelessWidget {
  const ShiftsPage({super.key});

  Future<void> _delete(BuildContext context, Shift s, Future<void> Function() reload) async {
    final shifts = context.read<ShiftRepository>();
    final locations = context.read<LocationRepository>();

    // Server xoá ca là xoá luôn các địa điểm dùng ca đó (không báo lỗi), nên chặn trước ở đây.
    try {
      final used = (await locations.list()).items.where((l) => l.shiftId == s.id).toList();
      if (used.isNotEmpty) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Không thể xoá ca'),
            content: Text('Ca "${s.name}" đang được dùng bởi: ${used.map((l) => l.name).join(', ')}.\n\n'
                'Hãy đổi ca của các địa điểm này (hoặc xoá địa điểm) trước.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu'))],
          ),
        );
        return;
      }
    } catch (_) {
      if (!context.mounted) return;
      showSnack(context, 'Không kiểm tra được địa điểm đang dùng ca này, thử lại sau.');
      return;
    }

    if (!context.mounted) return;
    final ok = await confirmDialog(context, title: 'Xoá ca làm việc?', message: 'Ca "${s.name}" sẽ bị xoá.');
    if (!ok || !context.mounted) return;
    if (await guard(context, () => shifts.delete(s.id), success: 'Đã xoá ca')) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ShiftRepository>();
    return ResourceListPage<Shift>(
      title: 'Ca làm việc',
      load: () async => (await repo.list()).items,
      emptyIcon: Icons.schedule_outlined,
      emptyTitle: 'Chưa có ca làm việc',
      emptySubtitle: 'Cần ít nhất một ca để tạo địa điểm chấm công.',
      addLabel: 'Thêm ca',
      onAdd: (ctx) => showFormSheet(ctx, builder: (_) => const ShiftForm()),
      itemBuilder: (ctx, s, reload) => ItemCard(
        leading: const IconBadge(Icons.schedule_outlined),
        title: s.name,
        subtitle: Text('${s.range} · trễ quá ${s.lateToleranceMinutes} phút', style: const TextStyle(color: AppColors.textMuted)),
        trailing: IconButton(
          tooltip: 'Xoá',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          onPressed: () => _delete(ctx, s, reload),
        ),
        onTap: () async {
          if (await showFormSheet(ctx, builder: (_) => ShiftForm(existing: s))) await reload();
        },
      ),
    );
  }
}

class ShiftForm extends StatefulWidget {
  const ShiftForm({super.key, this.existing});
  final Shift? existing;

  @override
  State<ShiftForm> createState() => _ShiftFormState();
}

class _ShiftFormState extends State<ShiftForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _tolerance = TextEditingController(text: '${widget.existing?.lateToleranceMinutes ?? 10}');
  late TimeOfDay _start = widget.existing?.start ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay _end = widget.existing?.end ?? const TimeOfDay(hour: 17, minute: 0);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  bool get _timeOk => _minutes(_end) > _minutes(_start);

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || !_timeOk) {
      setState(() {}); // hiện lỗi giờ
      return;
    }
    final repo = context.read<ShiftRepository>();
    final nav = Navigator.of(context);
    final tolerance = int.parse(_tolerance.text.trim());
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      final e = widget.existing;
      if (e == null) {
        await repo.create(name: _name.text.trim(), start: Shift.formatApi(_start), end: Shift.formatApi(_end), lateToleranceMinutes: tolerance);
      } else {
        await repo.update(e.id, name: _name.text.trim(), start: Shift.formatApi(_start), end: Shift.formatApi(_end), lateToleranceMinutes: tolerance);
      }
    }, success: widget.existing == null ? 'Đã thêm ca' : 'Đã lưu thay đổi');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) nav.pop(true);
  }

  Widget _timeButton(String label, TimeOfDay t, bool isStart) => Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => _pick(isStart),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
              Text(Shift.formatShort(t), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Thêm ca làm việc' : 'Sửa ca làm việc',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên ca'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên ca' : null,
          ),
          const SizedBox(height: 14),
          Row(children: [_timeButton('Giờ vào', _start, true), const SizedBox(width: 12), _timeButton('Giờ ra', _end, false)]),
          if (!_timeOk)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('Giờ ra phải sau giờ vào', style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('shift-tolerance'), // giữ trạng thái lỗi khi dòng "Giờ ra phải sau giờ vào" xuất hiện/biến mất
            controller: _tolerance,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cho phép đi trễ (phút)', helperText: 'Quá số phút này tính là đi trễ'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Nhập số phút';
              if (n < 0 || n > 180) return 'Từ 0 đến 180 phút';
              return null;
            },
          ),
          const SizedBox(height: 20),
          BusyButton(label: 'Lưu', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

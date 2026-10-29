import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/leave.dart';
import '../../data/models/session.dart';
import '../../data/repositories/leave_repository.dart';
import '../auth/auth_controller.dart';
import '../shared/common.dart';

/// Đơn nghỉ phép. Nhân viên: xem/tạo/sửa/huỷ đơn của mình (khi còn chờ duyệt).
/// Admin/Manager: xem tất cả, duyệt hoặc từ chối; Admin còn xoá được đơn.
class LeavesPage extends StatefulWidget {
  const LeavesPage({super.key});

  @override
  State<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends State<LeavesPage> {
  late final UserRole _role = context.read<AuthController>().session?.role ?? UserRole.employee;
  late LeaveStatus? _filter = _isReviewer ? LeaveStatus.pending : null;

  List<Leave>? _items;
  String? _error;
  bool _loading = true;

  bool get _isReviewer => _role != UserRole.employee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<LeaveRepository>();
    setState(() {
      _loading = _items == null;
      _error = null;
    });
    try {
      final items = await repo.list(status: _filter);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Leave? existing}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LeaveFormPage(existing: existing)));
    if (saved == true) await _load();
  }

  Future<void> _cancel(Leave l) async {
    final ok = await confirmDialog(context,
        title: 'Huỷ đơn nghỉ phép?', message: 'Đơn ${formatDate(l.fromDate)} – ${formatDate(l.toDate)} sẽ bị xoá.', confirmLabel: 'Huỷ đơn');
    if (!ok || !mounted) return;
    final repo = context.read<LeaveRepository>();
    if (await guard(context, () => repo.delete(l.id), success: 'Đã huỷ đơn')) await _load();
  }

  Future<void> _review(Leave l, {required bool approve}) async {
    final ok = await confirmDialog(
      context,
      title: approve ? 'Duyệt đơn nghỉ phép?' : 'Từ chối đơn nghỉ phép?',
      message: '${l.userName}: ${formatDate(l.fromDate)} – ${formatDate(l.toDate)}\n"${l.reason}"',
      confirmLabel: approve ? 'Duyệt' : 'Từ chối',
      destructive: !approve,
    );
    if (!ok || !mounted) return;
    final repo = context.read<LeaveRepository>();
    if (await guard(context, () => repo.review(l.id, approve: approve), success: approve ? 'Đã duyệt đơn' : 'Đã từ chối đơn')) await _load();
  }

  Future<void> _adminDelete(Leave l) async {
    final ok = await confirmDialog(context, title: 'Xoá đơn nghỉ phép?', message: 'Đơn của ${l.userName} sẽ bị xoá vĩnh viễn.');
    if (!ok || !mounted) return;
    final repo = context.read<LeaveRepository>();
    if (await guard(context, () => repo.delete(l.id), success: 'Đã xoá đơn')) await _load();
  }

  Color _statusColor(LeaveStatus s) => switch (s) {
        LeaveStatus.pending => AppColors.amberDark,
        LeaveStatus.approved => AppColors.ok,
        LeaveStatus.rejected => AppColors.danger,
      };

  Widget _footer(Leave l) {
    final pending = l.status == LeaveStatus.pending;
    final buttons = <Widget>[];
    if (_isReviewer) {
      if (pending) {
        buttons.addAll([
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: () => _review(l, approve: false),
            child: const Text('Từ chối'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: AppColors.ok),
            onPressed: () => _review(l, approve: true),
            child: const Text('Duyệt'),
          ),
        ]);
      }
      if (_role == UserRole.admin) {
        buttons.insert(0, TextButton(onPressed: () => _adminDelete(l), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Xoá')));
      }
    } else if (pending) {
      buttons.addAll([
        TextButton(onPressed: () => _cancel(l), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Huỷ đơn')),
        OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: () => _openForm(existing: l), child: const Text('Sửa')),
      ]);
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 8, children: buttons),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items == null) {
      body = ErrorView(message: _error!, onRetry: _load);
    } else if (_items!.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 80),
        EmptyView(
          icon: Icons.beach_access_outlined,
          title: _filter == null ? 'Chưa có đơn nghỉ phép' : 'Không có đơn "${_filter!.label}"',
          subtitle: _isReviewer ? null : 'Bấm "Tạo đơn" để xin nghỉ phép.',
        ),
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final l = _items![i];
          final range = '${formatDate(l.fromDate)} – ${formatDate(l.toDate)}';
          return ItemCard(
            leading: const IconBadge(Icons.beach_access_outlined),
            title: _isReviewer ? l.userName : range,
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isReviewer) Text(range, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                Text(l.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
            trailing: StatusChip(l.status.label, _statusColor(l.status)),
            footer: _footer(l),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isReviewer ? 'Duyệt nghỉ phép' : 'Đơn nghỉ phép', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final s in <LeaveStatus?>[null, ...LeaveStatus.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s?.label ?? 'Tất cả'),
                      selected: _filter == s,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(color: _filter == s ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                      checkmarkColor: Colors.white,
                      onSelected: (_) {
                        setState(() => _filter = s);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: RefreshIndicator(color: AppColors.ink, onRefresh: _load, child: body)),
        ],
      ),
      floatingActionButton: _isReviewer
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.ink,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo đơn', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

class LeaveFormPage extends StatefulWidget {
  const LeaveFormPage({super.key, this.existing});
  final Leave? existing;

  @override
  State<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  final _form = GlobalKey<FormState>();
  late final _reason = TextEditingController(text: widget.existing?.reason);
  DateTimeRange? _range;
  bool _rangeError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) _range = DateTimeRange(start: e.fromDate, end: e.toDate);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Chọn ngày nghỉ',
      saveText: 'Xong',
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _rangeError = false;
      });
    }
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (_range == null) setState(() => _rangeError = true);
    if (!valid || _range == null) return;
    final repo = context.read<LeaveRepository>();
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      final e = widget.existing;
      if (e == null) {
        await repo.create(from: _range!.start, to: _range!.end, reason: _reason.text.trim());
      } else {
        await repo.update(e.id, from: _range!.start, to: _range!.end, reason: _reason.text.trim());
      }
    }, success: widget.existing == null ? 'Đã gửi đơn nghỉ phép' : 'Đã lưu thay đổi');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final days = _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Tạo đơn nghỉ phép' : 'Sửa đơn nghỉ phép', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                side: BorderSide(color: _rangeError ? AppColors.danger : AppColors.ink, width: 1.2),
              ),
              onPressed: _pickRange,
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _range == null ? 'Chọn ngày nghỉ' : '${formatDate(_range!.start)} – ${formatDate(_range!.end)}  ($days ngày)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (_rangeError)
              const Padding(padding: EdgeInsets.only(top: 6, left: 4), child: Text('Hãy chọn ngày nghỉ', style: TextStyle(color: AppColors.danger, fontSize: 12))),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('leave-reason'), // giữ trạng thái lỗi khi thông báo chọn ngày chèn thêm vào danh sách
              controller: _reason,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Lý do', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập lý do nghỉ' : null,
            ),
            const SizedBox(height: 24),
            BusyButton(label: widget.existing == null ? 'Gửi đơn' : 'Lưu thay đổi', busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

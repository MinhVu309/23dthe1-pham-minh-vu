import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/department.dart';
import '../../data/repositories/department_repository.dart';
import '../shared/common.dart';
import '../shared/resource_list_page.dart';

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});

  Future<void> _delete(BuildContext context, Department d, Future<void> Function() reload) async {
    final repo = context.read<DepartmentRepository>();
    final ok = await confirmDialog(context,
        title: 'Xoá phòng ban?',
        message: 'Phòng ban "${d.name}" sẽ bị xoá. Nhân viên thuộc phòng ban này sẽ không còn phòng ban.');
    if (!ok || !context.mounted) return;
    if (await guard(context, () => repo.delete(d.id), success: 'Đã xoá phòng ban')) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<DepartmentRepository>();
    return ResourceListPage<Department>(
      title: 'Phòng ban',
      load: () async => (await repo.list()).items,
      emptyIcon: Icons.apartment_outlined,
      emptyTitle: 'Chưa có phòng ban',
      emptySubtitle: 'Bấm "Thêm" để tạo phòng ban đầu tiên.',
      addLabel: 'Thêm phòng ban',
      onAdd: (ctx) => showFormSheet(ctx, builder: (_) => const DepartmentForm()),
      itemBuilder: (ctx, d, reload) => ItemCard(
        leading: const IconBadge(Icons.apartment_outlined),
        title: d.name,
        subtitle: (d.description == null || d.description!.isEmpty)
            ? null
            : Text(d.description!, style: const TextStyle(color: AppColors.textMuted)),
        trailing: IconButton(
          tooltip: 'Xoá',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          onPressed: () => _delete(ctx, d, reload),
        ),
        onTap: () async {
          if (await showFormSheet(ctx, builder: (_) => DepartmentForm(existing: d))) await reload();
        },
      ),
    );
  }
}

class DepartmentForm extends StatefulWidget {
  const DepartmentForm({super.key, this.existing});
  final Department? existing;

  @override
  State<DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends State<DepartmentForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _desc = TextEditingController(text: widget.existing?.description);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<DepartmentRepository>();
    final nav = Navigator.of(context);
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      final e = widget.existing;
      if (e == null) {
        await repo.create(name: _name.text.trim(), description: description);
      } else {
        await repo.update(e.id, name: _name.text.trim(), description: description);
      }
    }, success: widget.existing == null ? 'Đã thêm phòng ban' : 'Đã lưu thay đổi');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Thêm phòng ban' : 'Sửa phòng ban',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Tên phòng ban'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên phòng ban' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _desc,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Mô tả (không bắt buộc)'),
          ),
          const SizedBox(height: 20),
          BusyButton(label: 'Lưu', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models/department.dart';
import '../../data/models/employee.dart';
import '../../data/repositories/department_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../auth/auth_controller.dart';
import '../shared/common.dart';
import 'employee_form_page.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  List<Department> _departments = const [];
  final List<Employee> _items = [];
  int _total = 0;
  int _page = 0;
  int? _departmentId;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadDepartments();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final r = await context.read<DepartmentRepository>().list();
      if (mounted) setState(() => _departments = r.items);
    } on ApiException {
      // Chỉ phục vụ bộ lọc; bỏ qua lỗi, danh sách nhân viên vẫn dùng được.
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final r = await context.read<EmployeeRepository>().list(q: _search.text, departmentId: _departmentId, page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _total = r.total;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final r = await context.read<EmployeeRepository>().list(q: _search.text, departmentId: _departmentId, page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _total = r.total;
        _page++;
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadFirstPage);
  }

  Future<void> _openForm({Employee? existing}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EmployeeFormPage(existing: existing)));
    if (saved == true) await _loadFirstPage();
  }

  Future<void> _toggleActive(Employee e) async {
    final lock = e.isActive;
    final ok = await confirmDialog(
      context,
      title: lock ? 'Khoá tài khoản?' : 'Mở khoá tài khoản?',
      message: lock ? '${e.fullName} sẽ không thể đăng nhập cho tới khi được mở khoá.' : '${e.fullName} sẽ đăng nhập được trở lại.',
      confirmLabel: lock ? 'Khoá' : 'Mở khoá',
      destructive: lock,
    );
    if (!ok || !mounted) return;
    final repo = context.read<EmployeeRepository>();
    final done = await guard(
      context,
      () => repo.update(e.id, fullName: e.fullName, employeeCode: e.employeeCode, departmentId: e.departmentId, isActive: !e.isActive),
      success: lock ? 'Đã khoá tài khoản' : 'Đã mở khoá tài khoản',
    );
    if (done && mounted) {
      final i = _items.indexWhere((x) => x.id == e.id);
      if (i >= 0) setState(() => _items[i] = e.copyWith(isActive: !e.isActive));
    }
  }

  Future<void> _delete(Employee e) async {
    final ok = await confirmDialog(
      context,
      title: 'Xoá nhân viên?',
      message: 'Tài khoản "${e.fullName}" và toàn bộ dữ liệu chấm công, đơn nghỉ phép của họ sẽ bị xoá vĩnh viễn.\n\n'
          'Nếu chỉ muốn ngăn đăng nhập, hãy chọn "Khoá" thay vì xoá.',
    );
    if (!ok || !mounted) return;
    final repo = context.read<EmployeeRepository>();
    final done = await guard(context, () => repo.delete(e.id), success: 'Đã xoá nhân viên');
    if (done && mounted) {
      setState(() {
        _items.removeWhere((x) => x.id == e.id);
        _total = (_total - 1).clamp(0, 1 << 30);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfId = context.read<AuthController>().session?.userId;

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(message: _error!, onRetry: _loadFirstPage);
    } else if (_items.isEmpty) {
      final filtering = _search.text.trim().isNotEmpty || _departmentId != null;
      body = ListView(children: [
        const SizedBox(height: 80),
        EmptyView(
          icon: Icons.groups_2_outlined,
          title: filtering ? 'Không tìm thấy nhân viên' : 'Chưa có nhân viên',
          subtitle: filtering ? 'Thử đổi từ khoá hoặc bỏ lọc phòng ban.' : 'Bấm "Thêm nhân viên" để tạo tài khoản.',
        ),
      ]);
    } else {
      body = ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == _items.length) {
            if (_loadingMore) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
            if (_items.length < _total) {
              return TextButton(onPressed: _loadMore, child: const Text('Tải thêm'));
            }
            return const SizedBox(height: 4);
          }
          return _EmployeeTile(
            employee: _items[i],
            isSelf: _items[i].id == selfId,
            onEdit: () => _openForm(existing: _items[i]),
            onToggle: () => _toggleActive(_items[i]),
            onDelete: () => _delete(_items[i]),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _loadFirstPage();
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, email, mã nhân viên',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              _loadFirstPage();
                              setState(() {});
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('dept-$_departmentId-${_departments.length}'),
                        initialValue: _departmentId,
                        isExpanded: true,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.apartment_outlined), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Tất cả phòng ban')),
                          for (final d in _departments) DropdownMenuItem<int?>(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          setState(() => _departmentId = v);
                          _loadFirstPage();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$_total người', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: RefreshIndicator(color: AppColors.ink, onRefresh: _loadFirstPage, child: body)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Thêm nhân viên', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

enum _Action { edit, toggle, delete }

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.isSelf, required this.onEdit, required this.onToggle, required this.onDelete});

  final Employee employee;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return ItemCard(
      onTap: onEdit,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: e.isActive ? AppColors.ink : AppColors.paperDeep,
        child: Text(_initials(e.fullName), style: TextStyle(color: e.isActive ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w800)),
      ),
      title: isSelf ? '${e.fullName} (Bạn)' : e.fullName,
      subtitle: Text(e.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      trailing: PopupMenuButton<_Action>(
        tooltip: 'Tuỳ chọn',
        onSelected: (a) => switch (a) {
          _Action.edit => onEdit(),
          _Action.toggle => onToggle(),
          _Action.delete => onDelete(),
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: _Action.edit, child: Text('Sửa')),
          if (!isSelf) PopupMenuItem(value: _Action.toggle, child: Text(e.isActive ? 'Khoá tài khoản' : 'Mở khoá')),
          if (!isSelf) const PopupMenuItem(value: _Action.delete, child: Text('Xoá', style: TextStyle(color: AppColors.danger))),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (!e.isActive) const StatusChip('Đã khoá', AppColors.danger),
            if (e.employeeCode != null && e.employeeCode!.isNotEmpty) StatusChip(e.employeeCode!, AppColors.inkSoft),
            if (e.departmentName != null) StatusChip(e.departmentName!, AppColors.inkSoft),
            if (e.hasFace) const StatusChip('Đã đăng ký mặt', AppColors.ok),
          ],
        ),
      ),
    );
  }
}

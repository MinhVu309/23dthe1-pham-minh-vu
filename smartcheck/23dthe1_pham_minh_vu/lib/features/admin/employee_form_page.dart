import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/department.dart';
import '../../data/models/employee.dart';
import '../../data/models/session.dart';
import '../../data/repositories/department_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/register_page.dart' show validateEmail, validatePassword;
import '../shared/common.dart';

/// Tạo mới (`existing == null`) hoặc sửa nhân viên. Khi sửa sẽ tải chi tiết để biết role hiện tại.
class EmployeeFormPage extends StatefulWidget {
  const EmployeeFormPage({super.key, this.existing});
  final Employee? existing;

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName);
  late final _email = TextEditingController(text: widget.existing?.email);
  final _password = TextEditingController();
  late final _code = TextEditingController(text: widget.existing?.employeeCode);

  List<Department> _departments = const [];
  int? _departmentId;
  UserRole _role = UserRole.employee;
  bool _isActive = true;
  bool _hidePassword = true;

  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _departmentId = widget.existing?.departmentId;
    _isActive = widget.existing?.isActive ?? true;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final departments = context.read<DepartmentRepository>();
    final employees = context.read<EmployeeRepository>();
    try {
      final deps = await departments.list();
      Employee? detail;
      if (_isEdit) detail = await employees.get(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        _departments = deps.items;
        if (detail != null) {
          _role = detail.role ?? UserRole.employee;
          _isActive = detail.isActive;
          _departmentId = detail.departmentId;
        }
        if (!_departments.any((d) => d.id == _departmentId)) _departmentId = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<EmployeeRepository>();
    final nav = Navigator.of(context);
    final code = _code.text.trim().isEmpty ? null : _code.text.trim();
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      if (_isEdit) {
        await repo.update(widget.existing!.id,
            fullName: _name.text.trim(), employeeCode: code, departmentId: _departmentId, role: _role, isActive: _isActive);
      } else {
        await repo.create(
            email: _email.text.trim(), password: _password.text, fullName: _name.text.trim(), employeeCode: code, departmentId: _departmentId, role: _role);
      }
    }, success: _isEdit ? 'Đã lưu thay đổi' : 'Đã tạo nhân viên');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final selfId = context.read<AuthController>().session?.userId;
    final isSelf = _isEdit && widget.existing!.id == selfId;

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_loadError != null) {
      body = ErrorView(message: _loadError!, onRetry: _load);
    } else {
      body = Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập họ và tên' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              enabled: !_isEdit,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                helperText: _isEdit ? 'Không đổi được email sau khi tạo' : null,
              ),
              validator: validateEmail,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: 'Tối thiểu 6 ký tự, gồm chữ thường và chữ số',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
                validator: validatePassword,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _code,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Mã nhân viên (không bắt buộc)', prefixIcon: Icon(Icons.confirmation_number_outlined)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _departmentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Phòng ban', prefixIcon: Icon(Icons.apartment_outlined)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Không thuộc phòng ban nào')),
                for (final d in _departments) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => setState(() => _departmentId = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: InputDecoration(
                labelText: 'Vai trò',
                prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                helperText: isSelf ? 'Bạn không thể đổi vai trò của chính mình' : null,
              ),
              items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: isSelf ? null : (v) => setState(() => _role = v ?? _role),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                activeTrackColor: AppColors.ok,
                title: const Text('Tài khoản đang hoạt động', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(isSelf ? 'Bạn không thể tự khoá tài khoản của mình' : 'Tắt để khoá, người này sẽ không đăng nhập được'),
                value: _isActive,
                onChanged: isSelf ? null : (v) => setState(() => _isActive = v),
              ),
            ],
            const SizedBox(height: 22),
            BusyButton(label: _isEdit ? 'Lưu thay đổi' : 'Tạo nhân viên', busy: _busy, onPressed: _save),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa nhân viên' : 'Thêm nhân viên', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: body,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/profile.dart';
import '../auth/auth_controller.dart';

final _phonePattern = RegExp(r'^\+?[0-9 ]{9,15}$'); // cùng luật với server

String? validateFullName(String? v) {
  final s = v?.trim() ?? '';
  if (s.length < 2) return 'Nhập họ và tên (ít nhất 2 ký tự).';
  if (s.length > 100) return 'Họ và tên tối đa 100 ký tự.';
  return null;
}

/// Trống là hợp lệ (xoá số điện thoại).
String? validatePhone(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  return _phonePattern.hasMatch(s) ? null : 'Số điện thoại gồm 9–15 chữ số, có thể bắt đầu bằng +.';
}

/// Sửa họ tên và số điện thoại. Email, mã nhân viên, phòng ban do quản trị viên quản lý nên chỉ hiện để xem.
/// Lưu xong thì đóng và trả [Profile] mới.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});
  final Profile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final nav = Navigator.of(context);
    try {
      final saved = await auth.updateProfile(_name.text, _phone.text.trim().isEmpty ? null : _phone.text);
      nav.pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) NoticeBanner(_error!),
                  TextFormField(
                    key: const Key('profile-name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: validateFullName,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('profile-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(labelText: 'Số điện thoại (không bắt buộc)', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 14),
                  _readOnly(Icons.mail_outline_rounded, 'Email', p.email, 'Email dùng để đăng nhập nên không đổi được.'),
                  if (p.employeeCode != null) ...[
                    const SizedBox(height: 14),
                    _readOnly(Icons.confirmation_number_outlined, 'Mã nhân viên', p.employeeCode!, 'Do quản trị viên cấp.'),
                  ],
                  const SizedBox(height: 26),
                  BusyButton(label: 'Lưu thay đổi', busy: _busy, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnly(IconData icon, String label, String value, String helper) => TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon),
          fillColor: AppColors.paperDeep.withValues(alpha: 0.5),
        ),
      );
}

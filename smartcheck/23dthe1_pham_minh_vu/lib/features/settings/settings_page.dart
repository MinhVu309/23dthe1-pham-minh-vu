import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/biometric_service.dart';
import '../auth/auth_controller.dart';
import '../auth/biometric_offer.dart';
import 'edit_profile_page.dart';

/// Cài đặt: hồ sơ cá nhân, cỡ chữ, màu nền, đăng nhập bằng vân tay/khuôn mặt.
/// Cỡ chữ và màu nền đổi là áp dụng ngay cho cả app và được nhớ trên máy này.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Profile? _profile;
  String? _profileError;
  BiometricSupport? _support;
  bool _bioOn = false;
  bool _bioBusy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBiometric();
  }

  Future<void> _loadProfile() async {
    setState(() => _profileError = null);
    try {
      final p = await context.read<AuthApi>().me();
      if (mounted) setState(() => _profile = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _profileError = e.message);
    }
  }

  Future<void> _loadBiometric() async {
    final auth = context.read<AuthController>();
    final support = await auth.biometricSupport();
    final on = await auth.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _support = support;
      _bioOn = on;
    });
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<Profile>(MaterialPageRoute(builder: (_) => EditProfilePage(profile: _profile!)));
    if (saved != null && mounted) {
      setState(() => _profile = saved);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    }
  }

  Future<void> _toggleBiometric(bool on) async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bioBusy = true);
    try {
      if (on) {
        _bioOn = await enableBiometricWithFeedback(messenger, auth, _support?.label ?? 'sinh trắc học');
      } else {
        await auth.disableBiometric();
        _bioOn = false;
        messenger.showSnackBar(const SnackBar(content: Text('Đã tắt đăng nhập bằng sinh trắc học trên máy này.')));
      }
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final support = _support;
    final canUseBio = support != null && support.available;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _section('Hồ sơ cá nhân'),
            _Card(child: _profileCard()),
            _section('Cỡ chữ'),
            _Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final s in AppTextSize.values)
                    ChoiceChip(
                      key: Key('text-size-${s.name}'),
                      label: Text(s.label),
                      selected: settings.textSize == s,
                      onSelected: (_) => settings.setTextSize(s),
                    ),
                ]),
                const SizedBox(height: 12),
                const Text('Xem trước', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                const Text('Chấm công đúng người, đúng chỗ, đúng giờ.', style: TextStyle(color: AppColors.ink)),
              ]),
            ),
            _section('Màu nền'),
            _Card(
              child: Wrap(spacing: 14, runSpacing: 14, children: [
                for (final b in AppBackground.values) _Swatch(b, selected: settings.background == b, onTap: () => settings.setBackground(b)),
              ]),
            ),
            _section('Bảo mật'),
            _Card(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                key: const Key('biometric-switch'),
                secondary: const Icon(Icons.fingerprint_rounded),
                title: Text(canUseBio ? 'Đăng nhập bằng ${support.label}' : 'Đăng nhập bằng vân tay/khuôn mặt'),
                subtitle: Text(
                  support == null
                      ? 'Đang kiểm tra thiết bị…'
                      : canUseBio
                          ? 'Bỏ qua bước nhập mật khẩu và OTP trên máy này.'
                          : support.reason ?? 'Thiết bị này không hỗ trợ.',
                ),
                value: _bioOn,
                onChanged: (!canUseBio || _bioBusy) ? null : _toggleBiometric,
              ),
            ),
            if (!settings.isDefault) ...[
              const SizedBox(height: 18),
              TextButton.icon(
                key: const Key('reset-appearance'),
                onPressed: settings.reset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Khôi phục giao diện mặc định'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileCard() {
    final p = _profile;
    if (p == null) {
      if (_profileError != null) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NoticeBanner(_profileError!),
          OutlinedButton.icon(onPressed: _loadProfile, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
        ]);
      }
      return const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
    }
    return Row(children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.brand,
        child: Text(_initials(p.fullName.isEmpty ? p.email : p.fullName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.fullName.isEmpty ? p.email : p.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(p.email, style: const TextStyle(color: AppColors.textMuted)),
          Text(p.phoneNumber ?? 'Chưa có số điện thoại', style: const TextStyle(color: AppColors.textMuted)),
        ]),
      ),
      IconButton.filledTonal(key: const Key('edit-profile'), onPressed: _editProfile, icon: const Icon(Icons.edit_outlined), tooltip: 'Sửa hồ sơ'),
    ]);
  }

  static Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 8),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
      );

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.paperDeep)),
        child: child,
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.background, {required this.selected, required this.onTap});
  final AppBackground background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Màu nền ${background.label}',
        child: InkWell(
          key: Key('background-${background.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 70,
            child: Column(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background.page,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.brand : AppColors.paperDeep, width: selected ? 3 : 1.5),
                ),
                child: selected ? const Icon(Icons.check_rounded, color: AppColors.brandDark) : null,
              ),
              const SizedBox(height: 6),
              Text(background.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: AppColors.ink)),
            ]),
          ),
        ),
      );
}


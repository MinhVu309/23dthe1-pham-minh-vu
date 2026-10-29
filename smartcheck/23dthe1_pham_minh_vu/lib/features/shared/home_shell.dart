import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/session.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/auth_controller.dart';

/// Một chức năng sẽ có ở các giai đoạn sau (hiện hiển thị mờ).
class HomeModule {
  const HomeModule(this.icon, this.title, this.subtitle, {this.builder});
  final IconData icon;
  final String title;
  final String subtitle;

  /// Màn hình mở ra khi bấm; `null` nghĩa là chưa làm (hiện mờ "Sắp có").
  final WidgetBuilder? builder;
}

/// Khung trang chủ dùng chung cho 3 role: đầu trang mực + thẻ hồ sơ + danh sách chức năng.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.tagline, required this.modules});

  final String tagline;
  final List<HomeModule> modules;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Profile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<AuthApi>().me();
      if (mounted) setState(() => _profile = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập và nhập OTP lại lần sau.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<AuthController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    if (session == null) return const SizedBox.shrink();
    final initials = _initials(session.fullName.isNotEmpty ? session.fullName : session.email);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.ink,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    const Positioned.fill(child: CustomPaint(painter: DialPainter())),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 12, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.amber,
                                  child: Text(initials,
                                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Đăng xuất',
                                  color: Colors.white,
                                  icon: const Icon(Icons.logout_rounded),
                                  onPressed: _confirmLogout,
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text('Xin chào,', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(session.fullName.isEmpty ? session.email : session.fullName,
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(session.role.label,
                                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                            const SizedBox(height: 10),
                            Text(widget.tagline, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _ProfileCard(session: session, profile: _profile, loading: _loading, error: _error, onRetry: _load),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.separated(
                itemCount: widget.modules.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text('Chức năng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    );
                  }
                  return _ModuleTile(widget.modules[i - 1]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session, required this.profile, required this.loading, required this.error, required this.onRetry});

  final Session session;
  final Profile? profile;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading && profile == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    } else if (error != null && profile == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoticeBanner(error!),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
        ],
      );
    } else {
      final p = profile!;
      body = Column(
        children: [
          _row(Icons.mail_outline_rounded, 'Email', p.email),
          _row(Icons.confirmation_number_outlined, 'Mã nhân viên', p.employeeCode ?? 'Chưa có'),
          _row(Icons.face_retouching_natural_outlined, 'Khuôn mặt', p.hasFace ? 'Đã đăng ký' : 'Chưa đăng ký'),
          _row(Icons.phone_android_rounded, 'Thiết bị', p.deviceBound ? 'Đã gắn với máy này' : 'Chưa gắn thiết bị'),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: body,
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.inkSoft),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.textMuted)),
            const Spacer(),
            const SizedBox(width: 16),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
            ),
          ],
        ),
      );
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile(this.module);
  final HomeModule module;

  @override
  Widget build(BuildContext context) {
    final enabled = module.builder != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => Navigator.of(context).push(MaterialPageRoute(builder: module.builder!)) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.paperDeep)),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(12)),
                  child: Icon(module.icon, color: AppColors.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                      Text(module.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
                else
                  const Text('Sắp có', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

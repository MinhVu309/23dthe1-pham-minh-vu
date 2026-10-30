import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/session.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_page.dart';
import 'common.dart';

/// Một chức năng của trang chủ. `builder == null` nghĩa là chưa làm (hiện mờ "Sắp có").
class HomeModule {
  const HomeModule(this.icon, this.title, this.subtitle, {this.builder, this.group});
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder? builder;

  /// Nhóm để lọc bằng chip phía trên danh sách (bỏ trống thì chỉ hiện ở "Tất cả").
  final String? group;
}

/// Dựng thẻ trạng thái ở đầu trang. `refreshToken` tăng lên mỗi lần kéo làm mới.
typedef SummaryBuilder = Widget Function(BuildContext context, int refreshToken);

/// Khung trang chủ dùng chung cho 3 role, theo bố cục: đầu trang xanh lá có lời chào và thẻ trạng thái,
/// tờ trắng bo tròn đè lên với chip lọc và các thẻ chức năng, thanh điều hướng dưới có nút cam ở giữa.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.tagline,
    required this.modules,
    required this.fab,
    required this.shortcuts,
    required this.summary,
  }) : assert(shortcuts.length == 2);

  final String tagline;
  final List<HomeModule> modules;

  /// Nút cam nổi ở giữa thanh điều hướng (việc dùng nhiều nhất của role).
  final HomeModule fab;

  /// Hai lối tắt hai bên nút giữa.
  final List<HomeModule> shortcuts;
  final SummaryBuilder summary;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Profile? _profile;
  String? _error;
  bool _loading = true;
  String? _group; // null = Tất cả
  int _refresh = 0;

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

  Future<void> _onRefresh() async {
    setState(() => _refresh++);
    await _load();
  }

  void _open(HomeModule m) {
    final b = m.builder;
    if (b != null) Navigator.of(context).push(MaterialPageRoute(builder: b));
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

  void _showProfile(Session session) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true, // cao hơn mặc định khi có nhiều dòng hoặc chữ lớn; cuộn được nếu vẫn thiếu chỗ
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Row(children: [
              CircleAvatar(radius: 26, backgroundColor: AppColors.brand, child: Text(_initials(session.fullName.isNotEmpty ? session.fullName : session.email), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.fullName.isEmpty ? session.email : session.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  StatusChip(session.role.label, AppColors.amberDark),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            _ProfileInfo(session: session, profile: _profile, loading: _loading, error: _error, onRetry: _load),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('open-settings'),
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
                if (mounted) _load(); // hồ sơ có thể vừa được sửa
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Cài đặt'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    if (session == null) return const SizedBox.shrink();
    final name = session.fullName.isEmpty ? session.email : session.fullName;

    final groups = <String>{for (final m in widget.modules) ?m.group}.toList();
    final showChips = widget.modules.length >= 5 && groups.length > 1;
    final visible = widget.modules.where((m) => _group == null || m.group == _group).toList();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HeaderBackdrop()),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 21, backgroundColor: Colors.white, child: Text(_initials(name), style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w800))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(widget.tagline, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5, height: 1.3)),
                          ),
                          IconButton(tooltip: 'Đăng xuất', color: Colors.white, icon: const Icon(Icons.logout_rounded), onPressed: _confirmLogout),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Xin chào,', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                      Row(children: [
                        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                          child: Text(session.role.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.only(right: 12), child: widget.summary(context, _refresh)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLowest, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                  child: RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: _onRefresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 130),
                      children: [
                        Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 14),
                        if (showChips) ...[
                          SizedBox(
                            height: 46,
                            child: FilterChips<String?>(options: [null, ...groups], selected: _group, labelOf: (g) => g ?? 'Tất cả', onChanged: (g) => setState(() => _group = g), padding: 20),
                          ),
                          const SizedBox(height: 10),
                        ] else
                          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 4), child: Text('Chức năng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink))),
                        for (var i = 0; i < visible.length; i++)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: _ModuleCard(visible[i], color: _accent(widget.modules.indexOf(visible[i])), onTap: () => _open(visible[i])),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNav(
              left: widget.shortcuts[0],
              right: widget.shortcuts[1],
              fab: widget.fab,
              onOpen: _open,
              onProfile: () => _showProfile(session),
            ),
          ),
        ],
      ),
    );
  }

  static Color _accent(int i) => const [AppColors.brand, AppColors.sky, AppColors.amber][i % 3];

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard(this.module, {required this.color, required this.onTap});

  final HomeModule module;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = module.builder != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.paperDeep),
              boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                  child: Icon(module.icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(module.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                if (enabled)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: AppColors.paper, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft, size: 22),
                  )
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

/// Thanh điều hướng dưới: Trang chủ · lối tắt · NÚT CAM GIỮA · lối tắt · Hồ sơ.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.left, required this.right, required this.fab, required this.onOpen, required this.onProfile});

  final HomeModule left;
  final HomeModule right;
  final HomeModule fab;
  final void Function(HomeModule) onOpen;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SizedBox(
        height: 74,
        child: Row(
          children: [
            _item(Icons.home_rounded, 'Trang chủ', selected: true, onTap: () {}),
            _item(left.icon, left.title, onTap: () => onOpen(left)),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Center(
                  child: Tooltip(
                    message: fab.title,
                    child: GestureDetector(
                      key: const Key('nav-fab'),
                      onTap: () => onOpen(fab),
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          gradient: AppColors.amberGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: AppColors.amber.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 10))],
                        ),
                        child: Icon(fab.icon, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _item(right.icon, right.title, onTap: () => onOpen(right)),
            _item(Icons.person_rounded, 'Hồ sơ', onTap: onProfile),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, {required VoidCallback onTap, bool selected = false}) {
    final color = selected ? AppColors.brand : AppColors.textMuted;
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thông tin hồ sơ trong bảng trượt "Hồ sơ" (email, mã nhân viên, khuôn mặt, thiết bị).
class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.session, required this.profile, required this.loading, required this.error, required this.onRetry});

  final Session session;
  final Profile? profile;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && profile == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
    }
    if (error != null && profile == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NoticeBanner(error!),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
      ]);
    }
    final p = profile!;
    return Column(children: [
      _row(Icons.mail_outline_rounded, 'Email', p.email),
      _row(Icons.phone_outlined, 'Số điện thoại', p.phoneNumber ?? 'Chưa có'),
      _row(Icons.confirmation_number_outlined, 'Mã nhân viên', p.employeeCode ?? 'Chưa có'),
      _row(Icons.face_retouching_natural_outlined, 'Khuôn mặt', p.hasFace ? 'Đã đăng ký' : 'Chưa đăng ký'),
      _row(Icons.phone_android_rounded, 'Thiết bị', p.deviceBound ? 'Đã gắn với máy này' : 'Chưa gắn thiết bị'),
    ]);
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.inkSoft),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.textMuted)),
            const Spacer(),
            const SizedBox(width: 16),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)))),
          ],
        ),
      );
}

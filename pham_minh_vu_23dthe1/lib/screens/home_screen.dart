import 'dart:async';

import 'package:flutter/material.dart';

import '../services/current_user_store.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/error_view.dart';
import '../widgets/keep_alive_wrapper.dart';
import 'market_screen.dart';
import 'menu_screen.dart';
import 'news_feed_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

/// Khung chính kiểu Facebook: AppBar (tên app + nút tròn) và TabBar 5 tab:
/// Bảng tin, Chợ, Thông báo (có badge), Cá nhân, Menu. Mỗi tab giữ trạng thái khi chuyển qua lại.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _notificationsTab = 2;
  static const _profileTab = 3;

  late final TabController _tabs = TabController(length: 5, vsync: this)..addListener(_onTabChanged);
  final _profileKey = GlobalKey<ProfileScreenState>();
  NotificationStore? _notifications;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentUser.addListener(_onProfileChanged);
    currentUser.load();
    _onProfileChanged();
    // Cập nhật badge định kỳ khi đang dùng app
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _notifications?.load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    currentUser.removeListener(_onProfileChanged);
    _tabs.dispose();
    _notifications?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _notifications?.load();
  }

  /// Có hồ sơ đăng nhập thì tạo kho thông báo (khóa lưu mốc "đã xem" theo id tài khoản) và tải lần đầu.
  void _onProfileChanged() {
    final profile = currentUser.profile;
    if (profile == null || _notifications != null || !mounted) return;
    final store = NotificationStore(userId: profile.id)..addListener(() => mounted ? setState(() {}) : null);
    store.load();
    setState(() => _notifications = store);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == _notificationsTab) {
      _notifications?.markAllSeen(); // badge về 0 ngay khi mở tab
      _notifications?.load();
    } else if (_tabs.index == _profileTab) {
      _profileKey.currentState?.refresh();
    }
  }

  void _comingSoon(String feature) => showSnack(context, '$feature sẽ cập nhật sau');

  Widget _tab(IconData icon, String label, {int badge = 0}) {
    return Tab(
      height: 52,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: badge > 0 ? '$label, $badge mới' : label,
          excludeSemantics: true,
          child: Badge(
            isLabelVisible: badge > 0,
            label: Text(badge > 99 ? '99+' : '$badge'),
            child: Icon(icon, size: 28),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications?.unreadCount ?? 0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '23DTHE1 - Phạm Minh Vũ',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
        actions: [
          CircleIconButton(icon: Icons.search, tooltip: 'Tìm kiếm', onPressed: () => _comingSoon('Tìm kiếm')),
          CircleIconButton(
            icon: Icons.chat_bubble_outline,
            tooltip: 'Tin nhắn',
            onPressed: () => _comingSoon('Tin nhắn'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            _tab(Icons.home_outlined, 'Bảng tin'),
            _tab(Icons.storefront_outlined, 'Chợ'),
            _tab(Icons.notifications_outlined, 'Thông báo', badge: unread),
            _tab(Icons.account_circle_outlined, 'Cá nhân'),
            _tab(Icons.menu, 'Menu'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const KeepAliveWrapper(child: NewsFeedScreen()),
          const KeepAliveWrapper(child: MarketScreen(embedded: true)),
          KeepAliveWrapper(child: NotificationsScreen(store: _notifications)),
          KeepAliveWrapper(child: ProfileScreen(key: _profileKey, embedded: true)),
          KeepAliveWrapper(child: MenuScreen(onOpenProfile: () => _tabs.animateTo(_profileTab))),
        ],
      ),
    );
  }
}

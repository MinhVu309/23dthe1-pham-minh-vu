import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/api_service.dart';
import '../services/current_user_store.dart';
import '../services/post_feed_controller.dart';
import '../widgets/error_view.dart';
import '../widgets/paged_post_list.dart';
import '../widgets/profile_header.dart';
import '../widgets/skeleton.dart';

/// Trang cá nhân: đầu trang (ảnh bìa, avatar, tên, giới thiệu) và các bài viết của người đó (phân trang).
/// [userId] == null là trang của chính mình (tab "Cá nhân"); [embedded] bỏ AppBar khi đặt trong tab.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId, this.embedded = false});

  final String? userId;
  final bool embedded;

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  String? _error;
  PostFeedController? _feed;
  String? _loadedFor;

  /// Id người cần xem; trang của mình thì chờ hồ sơ đăng nhập tải xong.
  String? get _id => widget.userId ?? currentUser.profile?.id;

  @override
  void initState() {
    super.initState();
    currentUser.addListener(_maybeStart);
    _maybeStart();
  }

  @override
  void dispose() {
    currentUser.removeListener(_maybeStart);
    _feed?.dispose();
    super.dispose();
  }

  void _maybeStart() {
    final id = _id;
    if (id == null || id == _loadedFor || !mounted) return;
    _loadedFor = id;
    _feed?.dispose();
    _feed = PostFeedController((page, size) => apiService.getProfilePosts(id, page: page, pageSize: size));
    setState(() {});
    _loadProfile(id);
  }

  Future<void> _loadProfile(String id) async {
    try {
      final profile = id == currentUser.profile?.id ? await apiService.getMyProfile() : await apiService.getProfile(id);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Gọi khi người dùng mở lại tab: tải lại hồ sơ và bài viết (VD vừa đăng bài ở Bảng tin).
  Future<void> refresh() async {
    final id = _id;
    if (id == null) return;
    await Future.wait([_loadProfile(id), if (_feed != null) _feed!.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(_profile?.displayName ?? 'Trang cá nhân')),
      body: body,
    );
  }

  Widget _body() {
    final feed = _feed;
    if (feed == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: refresh)
          : ListView(children: const [PostSkeleton(withImage: false)]);
    }
    if (_profile == null && _error != null) {
      return ErrorView(message: _error!, onRetry: refresh);
    }
    return PagedPostList(
      controller: feed,
      emptyMessage: 'Chưa có bài viết nào.',
      headerBuilder: (context) => [
        if (_profile != null)
          ProfileHeader(profile: _profile!)
        else
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

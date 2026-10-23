import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import '../services/current_user_store.dart';
import '../services/post_feed_controller.dart';
import '../widgets/composer_card.dart';
import '../widgets/error_view.dart';
import '../widgets/paged_post_list.dart';
import '../widgets/recent_posters_row.dart';
import 'post_form_screen.dart';
import 'profile_screen.dart';

/// Bảng tin: ô soạn bài, hàng người vừa đăng bài, rồi các bài viết (cuộn vô hạn, kéo để làm mới).
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final _feed = PostFeedController((page, size) => apiService.getPostsPage(page: page, pageSize: size));
  final _scroll = ScrollController();

  @override
  void dispose() {
    _feed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _compose({bool pickPhoto = false}) async {
    final created = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => PostFormScreen(pickImageOnOpen: pickPhoto)),
    );
    if (created == null || !mounted) return;
    _feed.insertTop(created);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    showSnack(context, 'Đã đăng bài viết');
  }

  void _openProfile(String userId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    return PagedPostList(
      controller: _feed,
      scrollController: _scroll,
      emptyMessage: 'Chưa có bài viết nào.\nHãy là người đầu tiên đăng bài!',
      emptyActionLabel: 'Tạo bài viết',
      onEmptyAction: _compose,
      headerBuilder: (context) => [
        ListenableBuilder(
          listenable: currentUser,
          builder: (_, _) => ComposerCard(
            avatarUrl: currentUser.profile?.avatarUrl ?? '',
            onCompose: _compose,
            onPickPhoto: () => _compose(pickPhoto: true),
          ),
        ),
        RecentPostersRow(posts: _feed.items, onOpenProfile: _openProfile),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../screens/post_form_screen.dart';
import '../screens/profile_screen.dart';
import '../services/api_service.dart';
import '../services/post_feed_controller.dart';
import 'comment_sheet.dart';
import 'error_view.dart';
import 'post_card.dart';
import 'safe_network_image.dart';

/// Nối PostCard với dữ liệu thật: thích, bình luận, chia sẻ, sửa, xóa, mở trang cá nhân.
/// Dùng chung cho mọi danh sách bài đăng (Bảng tin, trang cá nhân).
class FeedPostTile extends StatelessWidget {
  const FeedPostTile({super.key, required this.post, required this.controller});

  final Post post;
  final PostFeedController controller;

  Future<void> _like(BuildContext context) async {
    final error = await controller.toggleLike(post);
    if (error != null && context.mounted) showSnack(context, 'Không thể thích bài viết: $error', error: true);
  }

  Future<void> _share(BuildContext context) async {
    final text = [
      '${post.userName}: ${post.content.trim()}',
      if (SafeNetworkImage.isUrl(post.image)) post.image,
    ].join('\n');
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: 'Bài viết của ${post.userName}'));
    } catch (_) {
      if (context.mounted) showSnack(context, 'Không mở được hộp thoại chia sẻ', error: true);
    }
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => PostFormScreen(post: post)),
    );
    if (updated == null || !context.mounted) return;
    controller.replace(updated);
    showSnack(context, 'Đã cập nhật bài viết');
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa bài viết',
      message: 'Bạn có chắc muốn xóa bài viết này? Lượt thích và bình luận cũng sẽ bị xóa.',
    );
    if (!ok || !context.mounted) return;
    try {
      await apiService.deletePost(post.id);
      controller.remove(post.id);
      if (context.mounted) showSnack(context, 'Đã xóa bài viết');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, 'Xóa thất bại: ${e.message}', error: true);
    }
  }

  void _openProfile(BuildContext context) {
    final id = post.userId;
    if (id == null) return; // bài mẫu cũ không có chủ
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)));
  }

  @override
  Widget build(BuildContext context) {
    return PostCard(
      post: post,
      onLike: () => _like(context),
      // Bấm đúp ảnh chỉ để THÍCH (không bỏ thích)
      onDoubleTapLike: post.likedByMe ? null : () => _like(context),
      onComment: () => showCommentSheet(
        context,
        post: post,
        onCountChanged: (delta) => controller.adjustCommentCount(post.id, delta),
      ),
      onShare: () => _share(context),
      onEdit: () => _edit(context),
      onDelete: () => _delete(context),
      onOpenProfile: post.userId == null ? null : () => _openProfile(context),
    );
  }
}

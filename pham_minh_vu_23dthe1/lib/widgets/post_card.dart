import 'package:flutter/material.dart';

import '../config/formatters.dart';
import '../models/post.dart';
import '../theme/app_theme.dart';
import 'app_avatar.dart';
import 'double_tap_image.dart';
import 'expandable_text.dart';
import 'safe_network_image.dart';

enum PostMenuAction { edit, delete }

/// Thẻ bài viết kiểu Facebook. Widget thuần: chỉ hiển thị [post] và báo sự kiện qua callback,
/// việc gọi API do nơi dùng (FeedPostTile) xử lý nên dễ kiểm thử.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onDoubleTapLike,
    this.onComment,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.onOpenProfile,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onDoubleTapLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenProfile;

  bool get _showMenu => post.canEdit && (onEdit != null || onDelete != null);

  @override
  Widget build(BuildContext context) {
    final hasImage = SafeNetworkImage.isUrl(post.image);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          if (post.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ExpandableText(post.content.trim()),
            ),
          if (hasImage) DoubleTapImage(url: post.image, onDoubleTap: onDoubleTapLike),
          _counts(),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider()),
          _actions(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
      child: Row(
        children: [
          Semantics(
            button: onOpenProfile != null,
            label: 'Trang cá nhân của ${post.userName}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onOpenProfile,
              child: AppAvatar(url: post.userAvatar, size: 40),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onOpenProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          timeAgo(post.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                      const Text(' · ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const Icon(Icons.public, size: 13, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showMenu)
            PopupMenuButton<PostMenuAction>(
              tooltip: 'Tùy chọn bài viết',
              icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
              onSelected: (action) => action == PostMenuAction.edit ? onEdit?.call() : onDelete?.call(),
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(value: PostMenuAction.edit, child: Text('Sửa bài viết')),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: PostMenuAction.delete,
                    child: Text('Xóa bài viết', style: TextStyle(color: AppColors.danger)),
                  ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _counts() {
    if (post.likeCount <= 0 && post.commentCount <= 0) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          if (post.likeCount > 0) ...[
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.thumb_up, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              '${post.likeCount}',
              key: const Key('like_count'),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          const Spacer(),
          if (post.commentCount > 0)
            InkWell(
              onTap: onComment,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${post.commentCount} bình luận',
                  key: const Key('comment_count'),
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    final liked = post.likedByMe;
    final likeColor = liked ? AppColors.primary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          _ActionButton(
            key: const Key('like_button'),
            labelKey: const Key('like_label'),
            icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
            label: 'Thích',
            color: likeColor,
            semanticLabel: liked ? 'Bỏ thích bài viết' : 'Thích bài viết',
            onTap: onLike,
          ),
          _ActionButton(
            key: const Key('comment_button'),
            icon: Icons.mode_comment_outlined,
            label: 'Bình luận',
            color: AppColors.textSecondary,
            semanticLabel: 'Xem và viết bình luận',
            onTap: onComment,
          ),
          _ActionButton(
            key: const Key('share_button'),
            icon: Icons.share_outlined,
            label: 'Chia sẻ',
            color: AppColors.textSecondary,
            semanticLabel: 'Chia sẻ bài viết',
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    this.labelKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
  });

  final Key? labelKey;
  final IconData icon;
  final String label;
  final Color color;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            height: 48, // vùng bấm tối thiểu 48dp
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    key: labelKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

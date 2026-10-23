import 'package:flutter/material.dart';

import '../config/formatters.dart';
import '../models/app_notification.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/error_view.dart';
import 'post_detail_screen.dart';

/// Tab Thông báo: ai đó thích/bình luận bài của tôi trong 7 ngày gần nhất. Mục mới (chưa xem) được tô nền xanh nhạt.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.store});

  /// null khi hồ sơ đăng nhập chưa tải xong.
  final NotificationStore? store;

  @override
  Widget build(BuildContext context) {
    final store = this.store;
    if (store == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: store.load,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.loaded && store.loading) return const Center(child: CircularProgressIndicator());
          if (store.error != null && store.items.isEmpty) {
            return ErrorView(message: '${store.error}', onRetry: store.load);
          }
          if (store.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyView(
                  icon: Icons.notifications_none,
                  message: 'Chưa có thông báo nào.\nKhi ai đó thích hoặc bình luận bài của bạn, bạn sẽ thấy ở đây.',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: store.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 1),
            itemBuilder: (context, i) => _NotificationTile(
              item: store.items[i],
              highlighted: store.isHighlighted(store.items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.highlighted});

  final AppNotification item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final action = item.isComment ? ' đã bình luận bài viết của bạn' : ' đã thích bài viết của bạn';
    return Material(
      color: highlighted ? const Color(0xFFE7F3FF) : AppColors.card,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(postId: item.postId)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(url: item.actorAvatar, size: 48),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: item.isComment ? AppColors.green : AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(item.isComment ? Icons.mode_comment : Icons.thumb_up, size: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.3),
                        children: [
                          TextSpan(text: item.actorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: action),
                        ],
                      ),
                    ),
                    if (item.isComment && item.commentContent.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '"${item.commentContent}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo(item.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                        color: highlighted ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (highlighted)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 14),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: DecoratedBox(decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

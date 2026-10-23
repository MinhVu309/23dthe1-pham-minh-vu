import 'package:flutter/material.dart';

import '../services/post_feed_controller.dart';
import '../theme/app_theme.dart';
import 'error_view.dart';
import 'feed_post_tile.dart';
import 'skeleton.dart';

/// Danh sách bài đăng dùng chung cho Bảng tin và trang cá nhân: phần đầu tùy ý ([headerBuilder]),
/// skeleton khi tải lần đầu, kéo để làm mới, cuộn vô hạn (tải trang kế khi gần cuối),
/// trạng thái rỗng và lỗi có nút thử lại.
class PagedPostList extends StatefulWidget {
  const PagedPostList({
    super.key,
    required this.controller,
    this.headerBuilder,
    this.scrollController,
    this.emptyMessage = 'Chưa có bài viết nào.',
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final PostFeedController controller;

  /// Các widget đặt trước danh sách bài (ô soạn bài, hàng người vừa đăng, đầu trang cá nhân...).
  final List<Widget> Function(BuildContext context)? headerBuilder;
  final ScrollController? scrollController;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  State<PagedPostList> createState() => _PagedPostListState();
}

class _PagedPostListState extends State<PagedPostList> {
  ScrollController? _ownController;
  ScrollController get _scroll => widget.scrollController ?? (_ownController ??= ScrollController());

  // Còn cách đáy khoảng này thì bắt đầu tải trang kế (khoảng 1,5 thẻ bài)
  static const _loadMoreThreshold = 600.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (!widget.controller.loaded && !widget.controller.loading) widget.controller.refresh();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _ownController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) widget.controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final headers = widget.headerBuilder?.call(context) ?? const <Widget>[];

          if (!controller.loaded && controller.loading) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [...headers, const PostSkeleton(), const PostSkeleton(withImage: false), const PostSkeleton()],
            );
          }
          if (controller.error != null && controller.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ...headers,
                _ErrorBlock(message: controller.error!, onRetry: controller.refresh),
              ],
            );
          }
          if (controller.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ...headers,
                EmptyView(
                  icon: Icons.article_outlined,
                  message: widget.emptyMessage,
                  actionLabel: widget.emptyActionLabel,
                  onAction: widget.onEmptyAction,
                ),
              ],
            );
          }

          return ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: headers.length + controller.items.length + 1,
            itemBuilder: (context, index) {
              if (index < headers.length) return headers[index];
              final postIndex = index - headers.length;
              if (postIndex < controller.items.length) {
                return FeedPostTile(post: controller.items[postIndex], controller: controller);
              }
              return _Footer(controller: controller);
            },
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PostFeedController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    if (controller.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Không tải thêm được: ${controller.loadMoreError}', textAlign: TextAlign.center),
            TextButton(onPressed: controller.loadMore, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (!controller.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Bạn đã xem hết bài viết', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
        ],
      ),
    );
  }
}

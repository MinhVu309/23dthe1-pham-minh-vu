import 'package:flutter/material.dart';

import '../config/formatters.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/logout_button.dart';
import 'post_form_screen.dart';

/// News Feed kiểu Facebook: danh sách bài đăng, kéo để làm mới, thêm/sửa/xóa.
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

enum _PostMenu { edit, delete }

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  late Future<List<Post>> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.getPosts();
  }

  // Dùng block {} để closure của setState không trả về Future (Flutter sẽ báo lỗi và không rebuild)
  void _reload() {
    setState(() {
      _future = apiService.getPosts();
    });
  }

  Future<void> _openForm([Post? post]) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PostFormScreen(post: post)),
    );
    if (message == null || !mounted) return;
    _reload();
    showSnack(context, message);
  }

  Future<void> _delete(Post post) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa bài viết',
      message: 'Bạn có chắc muốn xóa bài viết của ${post.userName}?',
    );
    if (!ok || !mounted) return;
    try {
      await apiService.deletePost(post.id);
      if (!mounted) return;
      _reload();
      showSnack(context, 'Đã xóa bài viết');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, 'Xóa thất bại: ${e.message}', error: true);
    }
  }

  /// Like: lưu lại bằng PUT (tăng likeCount lên 1) rồi tải lại danh sách.
  Future<void> _like(Post post) async {
    try {
      await apiService.updatePost(post.copyWith(likeCount: post.likeCount + 1));
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, 'Không thể thích bài viết: ${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng tin'), actions: const [LogoutButton()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.edit),
        label: const Text('Đăng bài'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future.catchError((_) => <Post>[]);
        },
        child: FutureBuilder<List<Post>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: _reload);
            }
            final posts = snapshot.data!;
            if (posts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 120), Center(child: Text('Chưa có bài đăng nào'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88), // chừa chỗ cho nút "Đăng bài"
              itemCount: posts.length,
              itemBuilder: (context, index) => _PostCard(
                post: posts[index],
                onEdit: () => _openForm(posts[index]),
                onDelete: () => _delete(posts[index]),
                onLike: () => _like(posts[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
  });

  final Post post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng đầu: avatar + tên + thời gian + menu "..."
          ListTile(
            leading: ClipOval(
              child: SafeNetworkImage(
                url: post.userAvatar,
                width: 44,
                height: 44,
                fallbackIcon: Icons.person,
              ),
            ),
            title: Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(timeAgo(post.createdAt)),
            trailing: PopupMenuButton<_PostMenu>(
              tooltip: 'Tùy chọn',
              icon: const Icon(Icons.more_horiz),
              onSelected: (action) =>
                  action == _PostMenu.edit ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _PostMenu.edit, child: Text('Sửa bài viết')),
                PopupMenuItem(value: _PostMenu.delete, child: Text('Xóa bài viết')),
              ],
            ),
          ),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(post.content, style: textTheme.bodyLarge),
            ),
          if (post.image.trim().toLowerCase().startsWith('http'))
            SafeNetworkImage(url: post.image, width: double.infinity, height: 220),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.thumb_up, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text('${post.likeCount}'),
                const Spacer(),
                Text('${post.commentCount} bình luận'),
              ],
            ),
          ),
          const Divider(height: 16),
          // Hàng hành động: Thích / Bình luận / Chia sẻ
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onLike,
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: const Text('Thích'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => showSnack(context, 'Tính năng bình luận sẽ cập nhật sau'),
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: const Text('Bình luận'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => showSnack(context, 'Tính năng chia sẻ sẽ cập nhật sau'),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Chia sẻ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

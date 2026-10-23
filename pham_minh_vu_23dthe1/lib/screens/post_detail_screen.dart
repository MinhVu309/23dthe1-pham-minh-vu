import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import '../services/post_feed_controller.dart';
import '../widgets/paged_post_list.dart';

/// Một bài viết (mở từ thông báo). Dùng lại PagedPostList với danh sách một bài để có sẵn
/// thích/bình luận/sửa/xóa, trạng thái lỗi và kéo để làm mới.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostFeedController _feed = PostFeedController((page, size) async {
    final post = await apiService.getPostById(widget.postId);
    return PagedPosts(items: [post], page: 1, totalCount: 1, hasMore: false);
  });

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: PagedPostList(controller: _feed, emptyMessage: 'Bài viết này không còn tồn tại.'),
    );
  }
}

import 'post.dart';

/// Bình luận trên một bài đăng (api/PostApi/{id}/comments).
class Comment {
  final int id;
  final int postId;
  final String? userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;

  /// Chủ bình luận, chủ bài hoặc Admin mới được xóa
  final bool canDelete;

  const Comment({
    required this.id,
    required this.postId,
    this.userId,
    required this.userName,
    this.userAvatar = '',
    required this.content,
    required this.createdAt,
    this.canDelete = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String?,
      userName: json['userName'] as String? ?? 'Ẩn danh',
      userAvatar: json['userAvatar'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: parseServerTime(json['createdAt'] as String?),
      canDelete: json['canDelete'] as bool? ?? false,
    );
  }
}

/// Một trang bình luận kèm tổng số (header X-Total-Count).
class CommentPage {
  final List<Comment> items;
  final int total;

  const CommentPage({required this.items, required this.total});
}

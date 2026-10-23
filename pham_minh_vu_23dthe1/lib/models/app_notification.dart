import 'post.dart';

/// Thông báo: người khác thích hoặc bình luận bài của tôi (api/NotificationApi).
class AppNotification {
  final String type; // "like" hoặc "comment"
  final int postId;
  final String postSnippet;
  final String? actorId;
  final String actorName;
  final String actorAvatar;
  final String commentContent;
  final DateTime createdAt;

  const AppNotification({
    required this.type,
    required this.postId,
    this.postSnippet = '',
    this.actorId,
    required this.actorName,
    this.actorAvatar = '',
    this.commentContent = '',
    required this.createdAt,
  });

  bool get isComment => type == 'comment';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      type: json['type'] as String? ?? 'like',
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      postSnippet: json['postSnippet'] as String? ?? '',
      actorId: json['actorId'] as String?,
      actorName: json['actorName'] as String? ?? 'Ai đó',
      actorAvatar: json['actorAvatar'] as String? ?? '',
      commentContent: json['commentContent'] as String? ?? '',
      createdAt: parseServerTime(json['createdAt'] as String?),
    );
  }
}

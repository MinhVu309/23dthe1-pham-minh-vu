/// Bài đăng kiểu Facebook, trả về từ api/PostApi.
class Post {
  final int id;

  /// null với bài mẫu cũ không có chủ
  final String? userId;
  final String userName;
  final String userAvatar;
  final String content;
  final String image;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  /// Người đang xem đã thích bài này chưa (server tính theo token)
  final bool likedByMe;

  /// Người đang xem có được sửa/xóa không (chủ bài hoặc Admin) — quyết định hiện menu "..."
  final bool canEdit;

  const Post({
    this.id = 0,
    this.userId,
    required this.userName,
    this.userAvatar = '',
    required this.content,
    this.image = '',
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.canEdit = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String?,
      userName: json['userName'] as String? ?? 'Ẩn danh',
      userAvatar: json['userAvatar'] as String? ?? '',
      content: json['content'] as String? ?? '',
      image: json['image'] as String? ?? '',
      createdAt: parseServerTime(json['createdAt'] as String?),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      canEdit: json['canEdit'] as bool? ?? false,
    );
  }

  Post copyWith({
    String? content,
    String? image,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
  }) {
    return Post(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: content ?? this.content,
      image: image ?? this.image,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      canEdit: canEdit,
    );
  }
}

/// Một trang bài đăng: { items, page, pageSize, totalCount, hasMore }.
class PagedPosts {
  final List<Post> items;
  final int page;
  final int totalCount;
  final bool hasMore;

  const PagedPosts({required this.items, required this.page, required this.totalCount, required this.hasMore});

  factory PagedPosts.fromJson(Map<String, dynamic> json) {
    return PagedPosts(
      items: (json['items'] as List? ?? const [])
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Backend lưu giờ UTC nhưng khi đọc từ SQL Server thì chuỗi JSON không có
/// hậu tố "Z" (VD "2026-10-20T08:00:00"). DateTime.parse sẽ hiểu nhầm là giờ
/// địa phương, nên ở đây ép coi là UTC rồi đổi sang giờ địa phương.
DateTime parseServerTime(String? raw) {
  if (raw == null || raw.isEmpty) return DateTime.now();
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
  return DateTime.parse(hasZone ? raw : '${raw}Z').toLocal();
}

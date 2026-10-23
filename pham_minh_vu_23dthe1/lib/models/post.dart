/// Bài đăng kiểu Facebook, trả về từ api/PostApi.
class Post {
  final int id;
  final String userName;
  final String userAvatar;
  final String content;
  final String image;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  const Post({
    this.id = 0,
    required this.userName,
    this.userAvatar = '',
    required this.content,
    this.image = '',
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userName: json['userName'] as String? ?? 'Ẩn danh',
      userAvatar: json['userAvatar'] as String? ?? '',
      content: json['content'] as String? ?? '',
      image: json['image'] as String? ?? '',
      createdAt: parseServerTime(json['createdAt'] as String?),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'userName': userName,
        'userAvatar': userAvatar,
        'content': content,
        'image': image,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'likeCount': likeCount,
        'commentCount': commentCount,
      };

  Post copyWith({
    String? userName,
    String? userAvatar,
    String? content,
    String? image,
    int? likeCount,
    int? commentCount,
  }) {
    return Post(
      id: id,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      image: image ?? this.image,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
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

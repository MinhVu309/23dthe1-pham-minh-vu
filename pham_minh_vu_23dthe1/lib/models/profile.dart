/// Hồ sơ người dùng. api/ProfileApi/me trả đủ trường; hồ sơ công khai
/// (api/ProfileApi/{userId}) không có email, số điện thoại, tên đăng nhập.
class Profile {
  final String id;
  final String displayName;
  final String avatarUrl;
  final String coverUrl;
  final String bio;
  final int postCount;
  final String email;
  final List<String> roles;

  const Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl = '',
    this.coverUrl = '',
    this.bio = '',
    this.postCount = 0,
    this.email = '',
    this.roles = const [],
  });

  bool get isAdmin => roles.contains('Admin');

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      roles: (json['roles'] as List? ?? const []).whereType<String>().toList(),
    );
  }
}

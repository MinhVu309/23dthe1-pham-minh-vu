import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/models/app_notification.dart';
import 'package:pham_minh_vu_23dthe1/models/comment.dart';
import 'package:pham_minh_vu_23dthe1/models/post.dart';
import 'package:pham_minh_vu_23dthe1/models/profile.dart';
import 'package:pham_minh_vu_23dthe1/widgets/recent_posters_row.dart';

Post _post(int id, {String? userId, String name = 'A'}) =>
    Post(id: id, userId: userId, userName: name, content: 'x', createdAt: DateTime(2026, 10, 23));

void main() {
  group('Post.fromJson (API mạng xã hội)', () {
    final json = {
      'id': 39,
      'userId': 'u1',
      'userName': 'user1',
      'userAvatar': null,
      'content': 'Xin chào',
      'image': 'https://x/a.jpg',
      'createdAt': '2026-10-23T03:20:47.625329',
      'likeCount': 3,
      'commentCount': 2,
      'likedByMe': true,
      'canEdit': true,
    };

    test('đọc đủ trường mới: userId, likedByMe, canEdit', () {
      final p = Post.fromJson(json);
      expect(p.userId, 'u1');
      expect(p.likedByMe, isTrue);
      expect(p.canEdit, isTrue);
      expect(p.likeCount, 3);
      expect(p.commentCount, 2);
      expect(p.userAvatar, ''); // null -> chuỗi rỗng
    });

    test('JSON bản cũ (thiếu trường mới) vẫn đọc được, mặc định không thích và không được sửa', () {
      final p = Post.fromJson({'id': 1, 'userName': 'Bài mẫu', 'content': 'c', 'createdAt': '2026-10-20T08:00:00'});
      expect(p.userId, isNull);
      expect(p.likedByMe, isFalse);
      expect(p.canEdit, isFalse);
    });

    test('createdAt không có Z được hiểu là UTC', () {
      expect(Post.fromJson(json).createdAt.toUtc(), DateTime.utc(2026, 10, 23, 3, 20, 47, 625, 329));
    });

    test('copyWith đổi like/bình luận/nội dung nhưng giữ chủ bài và quyền sửa', () {
      final p = Post.fromJson(json).copyWith(likedByMe: false, likeCount: 2, commentCount: 5, content: 'Mới');
      expect(p.likedByMe, isFalse);
      expect(p.likeCount, 2);
      expect(p.commentCount, 5);
      expect(p.content, 'Mới');
      expect(p.userId, 'u1');
      expect(p.canEdit, isTrue);
      expect(p.createdAt, Post.fromJson(json).createdAt);
    });
  });

  test('PagedPosts.fromJson', () {
    final page = PagedPosts.fromJson({
      'items': [
        {'id': 1, 'userName': 'a', 'content': 'c', 'createdAt': '2026-10-23T01:00:00'},
        {'id': 2, 'userName': 'b', 'content': 'c', 'createdAt': '2026-10-23T02:00:00'},
      ],
      'page': 2,
      'pageSize': 2,
      'totalCount': 7,
      'hasMore': true,
    });
    expect(page.items.map((p) => p.id), [1, 2]);
    expect(page.page, 2);
    expect(page.totalCount, 7);
    expect(page.hasMore, isTrue);
  });

  test('Comment.fromJson và AppNotification.fromJson', () {
    final c = Comment.fromJson({
      'id': 5, 'postId': 9, 'userId': 'u2', 'userName': 'user2', 'userAvatar': null,
      'content': 'Hay!', 'createdAt': '2026-10-23T03:00:00', 'canDelete': true,
    });
    expect(c.canDelete, isTrue);
    expect(c.postId, 9);

    final n = AppNotification.fromJson({
      'type': 'comment', 'postId': 9, 'postSnippet': 'Bài', 'actorId': 'u2', 'actorName': 'user2',
      'commentContent': 'Hay!', 'createdAt': '2026-10-23T03:00:00',
    });
    expect(n.isComment, isTrue);
    expect(n.commentContent, 'Hay!');
    expect(AppNotification.fromJson({'type': 'like', 'postId': 1, 'createdAt': '2026-10-23T03:00:00'}).isComment, isFalse);
  });

  test('Profile.fromJson: hồ sơ công khai không có email/roles', () {
    final p = Profile.fromJson({'id': 'u1', 'displayName': 'User Một', 'bio': 'Xin chào', 'postCount': 4});
    expect(p.email, '');
    expect(p.isAdmin, isFalse);
    expect(Profile.fromJson({'id': 'a', 'displayName': 'A', 'roles': ['Admin']}).isAdmin, isTrue);
  });

  test('RecentPostersRow.distinctPosters: mỗi người một lần, bỏ bài không có chủ, giữ thứ tự mới nhất', () {
    final posts = [
      _post(5, userId: 'u1', name: 'Một'),
      _post(4), // bài mẫu cũ, không có chủ
      _post(3, userId: 'u2', name: 'Hai'),
      _post(2, userId: 'u1', name: 'Một'),
      _post(1, userId: 'u3', name: 'Ba'),
    ];
    expect(RecentPostersRow.distinctPosters(posts).map((p) => p.userId), ['u1', 'u2', 'u3']);
    expect(RecentPostersRow.distinctPosters(posts, max: 2).length, 2);
    expect(RecentPostersRow.distinctPosters([_post(1)]), isEmpty);
  });
}

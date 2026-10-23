import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pham_minh_vu_23dthe1/models/app_notification.dart';
import 'package:pham_minh_vu_23dthe1/models/post.dart';
import 'package:pham_minh_vu_23dthe1/services/api_client.dart';
import 'package:pham_minh_vu_23dthe1/services/api_service.dart';
import 'package:pham_minh_vu_23dthe1/services/notification_store.dart';
import 'package:pham_minh_vu_23dthe1/services/post_feed_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Post _p(int id, {bool liked = false, int likes = 0}) =>
    Post(id: id, userId: 'u', userName: 'n', content: 'c', createdAt: DateTime(2026, 10, 23), likedByMe: liked, likeCount: likes);

PagedPosts _page(List<Post> items, {int page = 1, bool hasMore = false}) =>
    PagedPosts(items: items, page: page, totalCount: items.length, hasMore: hasMore);

ApiService _api(Future<http.Response> Function(http.Request) handler) =>
    ApiService(client: ApiClient(baseUrl: 'http://x/api/', client: MockClient(handler)));

http.Response _json(int status, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PostFeedController - phân trang', () {
    test('refresh tải trang 1, loadMore nối trang 2 và bỏ bài trùng, hết trang thì dừng', () async {
      final calls = <int>[];
      final c = PostFeedController((page, size) async {
        calls.add(page);
        return page == 1 ? _page([_p(3), _p(2)], hasMore: true) : _page([_p(2), _p(1)], page: 2);
      }, pageSize: 2, api: _api((_) async => _json(200, {})));

      await c.refresh();
      expect(c.items.map((p) => p.id), [3, 2]);
      expect(c.hasMore, isTrue);

      await c.loadMore();
      expect(c.items.map((p) => p.id), [3, 2, 1]); // bài 2 bị trùng nên không lặp
      expect(c.hasMore, isFalse);

      await c.loadMore(); // hết trang: không gọi thêm
      expect(calls, [1, 2]);
    });

    test('lỗi trang đầu ghi vào error; lỗi tải thêm ghi vào loadMoreError và cho thử lại', () async {
      var fail = true;
      final c = PostFeedController((page, size) async {
        if (page == 1 && fail) throw const ApiException('Mất kết nối');
        return page == 1 ? _page([_p(1)], hasMore: true) : throw const ApiException('Lỗi trang 2');
      }, api: _api((_) async => _json(200, {})));

      await c.refresh();
      expect(c.error, 'Mất kết nối');
      expect(c.items, isEmpty);

      fail = false;
      await c.refresh();
      expect(c.error, isNull);
      await c.loadMore();
      expect(c.loadMoreError, 'Lỗi trang 2');
      expect(c.loadingMore, isFalse);
    });

    test('kết quả của lần refresh cũ về muộn bị bỏ qua', () async {
      final slow = <Future<PagedPosts> Function()>[
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return _page([_p(100)]);
        },
        () async => _page([_p(200)]),
      ];
      var i = 0;
      final c = PostFeedController((page, size) => slow[i++](), api: _api((_) async => _json(200, {})));
      final first = c.refresh();
      final second = c.refresh();
      await Future.wait([first, second]);
      expect(c.items.map((p) => p.id), [200]);
    });

    test('insertTop / replace / remove / adjustCommentCount', () async {
      final c = PostFeedController((page, size) async => _page([_p(1), _p(2)]), api: _api((_) async => _json(200, {})));
      await c.refresh();
      c.insertTop(_p(9));
      expect(c.items.first.id, 9);
      c.replace(_p(2).copyWith(content: 'sửa'));
      expect(c.items.firstWhere((p) => p.id == 2).content, 'sửa');
      c.adjustCommentCount(1, 1);
      c.adjustCommentCount(1, 1);
      c.adjustCommentCount(1, -1);
      expect(c.items.firstWhere((p) => p.id == 1).commentCount, 1);
      c.adjustCommentCount(1, -5); // không xuống dưới 0
      expect(c.items.firstWhere((p) => p.id == 1).commentCount, 0);
      c.remove(9);
      expect(c.items.any((p) => p.id == 9), isFalse);
    });
  });

  group('PostFeedController - thích kiểu optimistic', () {
    test('đổi giao diện NGAY trước khi server trả lời, rồi đồng bộ số thật', () async {
      Future<http.Response> handler(http.Request r) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _json(200, {'liked': true, 'likeCount': 8}); // server cho biết số thật là 8
      }

      final c = PostFeedController((page, size) async => _page([_p(1, likes: 4)]), api: _api(handler));
      await c.refresh();

      final pending = c.toggleLike(c.items.first);
      // chưa có phản hồi từ server nhưng đã đổi
      expect(c.items.first.likedByMe, isTrue);
      expect(c.items.first.likeCount, 5);

      expect(await pending, isNull);
      expect(c.items.first.likedByMe, isTrue);
      expect(c.items.first.likeCount, 8);
    });

    test('lỗi mạng: hoàn tác về trạng thái cũ và trả thông báo lỗi', () async {
      final c = PostFeedController(
        (page, size) async => _page([_p(1, liked: true, likes: 3)]),
        api: _api((_) async => _json(403, {'status': false, 'message': 'Không có quyền'})),
      );
      await c.refresh();

      final error = await c.toggleLike(c.items.first);
      expect(error, 'Không có quyền');
      expect(c.items.first.likedByMe, isTrue);
      expect(c.items.first.likeCount, 3);
    });

    test('bấm liên tiếp khi lần trước chưa xong: lần sau bị bỏ qua, server chỉ nhận một yêu cầu', () async {
      var requests = 0;
      final c = PostFeedController((page, size) async => _page([_p(1)]), api: _api((_) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _json(200, {'liked': true, 'likeCount': 1});
      }));
      await c.refresh();

      final a = c.toggleLike(c.items.first);
      final b = c.toggleLike(c.items.first);
      await Future.wait([a, b]);
      expect(requests, 1);
      expect(c.items.first.likedByMe, isTrue);
    });
  });

  group('NotificationStore - badge', () {
    final now = DateTime.utc(2026, 10, 23, 12);
    String iso(DateTime d) => d.toIso8601String();
    List<Map<String, Object>> twoItems() => [
          {'type': 'like', 'postId': 1, 'actorName': 'a', 'createdAt': iso(now.subtract(const Duration(hours: 1)))},
          {'type': 'comment', 'postId': 1, 'actorName': 'b', 'createdAt': iso(now.subtract(const Duration(days: 2)))},
        ];

    test('chưa từng xem: badge = tất cả; mở tab thì về 0 nhưng vẫn tô nổi các mục mới', () async {
      final store = NotificationStore(userId: 'u1', api: _api((_) async => _json(200, twoItems())));
      await store.load();
      expect(store.unreadCount, 2);

      await store.markAllSeen(now: now);
      expect(store.unreadCount, 0);
      expect(store.items.every(store.isHighlighted), isTrue); // lần mở đầu: tô cả hai
    });

    test('mốc xem được lưu: lần sau chỉ tính thông báo mới hơn mốc', () async {
      var store = NotificationStore(userId: 'u1', api: _api((_) async => _json(200, twoItems())));
      await store.load();
      await store.markAllSeen(now: now.subtract(const Duration(days: 1))); // đã xem từ hôm qua

      store = NotificationStore(userId: 'u1', api: _api((_) async => _json(200, twoItems())));
      await store.load();
      expect(store.unreadCount, 1); // chỉ thông báo cách đây 1 giờ mới hơn mốc
    });

    test('mốc xem tách riêng theo tài khoản', () async {
      final a = NotificationStore(userId: 'u1', api: _api((_) async => _json(200, twoItems())));
      await a.load();
      await a.markAllSeen(now: now.add(const Duration(days: 1)));

      final b = NotificationStore(userId: 'u2', api: _api((_) async => _json(200, twoItems())));
      await b.load();
      expect(b.unreadCount, 2);
    });

    test('lỗi tải ghi vào error và không làm mất danh sách đã có', () async {
      var fail = false;
      final store = NotificationStore(
        userId: 'u1',
        api: _api((_) async => fail ? _json(500, {}) : _json(200, twoItems())),
      );
      await store.load();
      fail = true;
      await store.load();
      expect(store.error, isNotNull);
      expect(store.items.length, 2);
      expect(store.items.first, isA<AppNotification>());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/models/post.dart';
import 'package:pham_minh_vu_23dthe1/theme/app_theme.dart';
import 'package:pham_minh_vu_23dthe1/widgets/post_card.dart';

Post _post({
  bool liked = false,
  bool canEdit = false,
  int likes = 0,
  int comments = 0,
  String content = 'Nội dung bài viết',
}) =>
    Post(
      id: 1,
      userId: 'u1',
      userName: 'Người Đăng',
      content: content,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      likeCount: likes,
      commentCount: comments,
      likedByMe: liked,
      canEdit: canEdit,
    );

Future<void> _pump(WidgetTester tester, PostCard card) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(body: SingleChildScrollView(child: card))));
}

Color _labelColor(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('like_label'))).style!.color!;

void main() {
  group('PostCard - nút Thích', () {
    testWidgets('chưa thích: nhãn và icon màu xám, icon viền', (tester) async {
      await _pump(tester, PostCard(post: _post(liked: false)));
      expect(_labelColor(tester), AppColors.textSecondary);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });

    testWidgets('đã thích (likedByMe): nhãn và icon đổi sang xanh, icon đặc', (tester) async {
      await _pump(tester, PostCard(post: _post(liked: true)));
      expect(_labelColor(tester), AppColors.primary);
      expect(find.byIcon(Icons.thumb_up), findsWidgets);
      expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
    });

    testWidgets('bấm Thích / Bình luận / Chia sẻ gọi đúng callback', (tester) async {
      var like = 0, comment = 0, share = 0;
      await _pump(
        tester,
        PostCard(post: _post(), onLike: () => like++, onComment: () => comment++, onShare: () => share++),
      );
      await tester.tap(find.byKey(const Key('like_button')));
      await tester.tap(find.byKey(const Key('comment_button')));
      await tester.tap(find.byKey(const Key('share_button')));
      expect([like, comment, share], [1, 1, 1]);
    });

    testWidgets('vùng bấm của 3 nút cao tối thiểu 48dp', (tester) async {
      await _pump(tester, PostCard(post: _post(), onLike: () {}, onComment: () {}, onShare: () {}));
      for (final key in ['like_button', 'comment_button', 'share_button']) {
        expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('PostCard - menu "..." theo canEdit', () {
    testWidgets('canEdit = false: KHÔNG có nút "..." dù có callback sửa/xóa', (tester) async {
      await _pump(tester, PostCard(post: _post(canEdit: false), onEdit: () {}, onDelete: () {}));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('canEdit = true: có nút "..." và menu Sửa/Xóa gọi đúng callback', (tester) async {
      var edit = 0, delete = 0;
      await _pump(tester, PostCard(post: _post(canEdit: true), onEdit: () => edit++, onDelete: () => delete++));
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Sửa bài viết'), findsOneWidget);
      expect(find.text('Xóa bài viết'), findsOneWidget);

      await tester.tap(find.text('Sửa bài viết'));
      await tester.pumpAndSettle();
      expect(edit, 1);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa bài viết'));
      await tester.pumpAndSettle();
      expect(delete, 1);
    });

    testWidgets('canEdit = true nhưng không có callback nào: không hiện menu', (tester) async {
      await _pump(tester, PostCard(post: _post(canEdit: true)));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });
  });

  group('PostCard - nội dung', () {
    testWidgets('hiện tên người đăng, nội dung và thời gian', (tester) async {
      await _pump(tester, PostCard(post: _post()));
      expect(find.text('Người Đăng'), findsOneWidget);
      expect(find.text('Nội dung bài viết'), findsOneWidget);
      expect(find.text('5 phút trước'), findsOneWidget);
    });

    testWidgets('hàng đếm: hiện số thích và số bình luận khi > 0, ẩn khi bằng 0', (tester) async {
      await _pump(tester, PostCard(post: _post(likes: 12, comments: 3)));
      expect(find.byKey(const Key('like_count')), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3 bình luận'), findsOneWidget);

      await _pump(tester, PostCard(post: _post()));
      expect(find.byKey(const Key('like_count')), findsNothing);
      expect(find.byKey(const Key('comment_count')), findsNothing);
    });

    testWidgets('nội dung dài có nút "Xem thêm", bấm thì hiện đủ; nội dung ngắn thì không có', (tester) async {
      final long = List.generate(40, (i) => 'Dòng số $i của một bài viết rất dài').join('\n');
      await _pump(tester, PostCard(post: _post(content: long)));
      expect(find.text('Xem thêm'), findsOneWidget);
      await tester.tap(find.text('Xem thêm'));
      await tester.pump();
      expect(find.text('Xem thêm'), findsNothing);

      await _pump(tester, PostCard(post: _post(content: 'Ngắn')));
      expect(find.text('Xem thêm'), findsNothing);
    });
  });
}

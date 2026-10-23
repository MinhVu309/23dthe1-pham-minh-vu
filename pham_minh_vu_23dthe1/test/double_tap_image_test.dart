import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/widgets/double_tap_image.dart';

void main() {
  Future<void> doubleTap(WidgetTester tester) async {
    final target = find.byType(DoubleTapImage);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(target);
  }

  testWidgets('bấm đúp: gọi onDoubleTap, hiện trái tim rồi tự biến mất', (tester) async {
    var likes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DoubleTapImage(url: '', onDoubleTap: () => likes++)),
    ));
    expect(find.byIcon(Icons.favorite), findsNothing); // chưa bấm: không có trái tim

    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 150));
    expect(likes, 1);
    expect(find.byIcon(Icons.favorite), findsOneWidget); // đang bay lên

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byIcon(Icons.favorite), findsNothing); // hết hiệu ứng
  });

  testWidgets('bấm một lần không thích và không hiện trái tim', (tester) async {
    var likes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DoubleTapImage(url: '', onDoubleTap: () => likes++)),
    ));
    await tester.tap(find.byType(DoubleTapImage));
    await tester.pump(const Duration(milliseconds: 500));
    expect(likes, 0);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('không có onDoubleTap (đã thích rồi) vẫn hiện trái tim nhưng không gọi gì', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DoubleTapImage(url: ''))));
    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}

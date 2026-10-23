import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/config/formatters.dart';
import 'package:pham_minh_vu_23dthe1/models/post.dart';
import 'package:pham_minh_vu_23dthe1/models/product_post.dart';

void main() {
  group('ProductPost', () {
    test('price là int hoặc double đều parse được', () {
      expect(ProductPost.fromJson({'id': 1, 'price': 10000}).price, 10000.0);
      expect(ProductPost.fromJson({'id': 1, 'price': 299000.5}).price, 299000.5);
    });

    test('image = "Cập nhật sau" vẫn giữ nguyên chuỗi, null thành rỗng', () {
      expect(ProductPost.fromJson({'image': 'Cập nhật sau'}).image, 'Cập nhật sau');
      expect(ProductPost.fromJson({'image': null}).image, '');
    });

    test('toJson: thêm mới không gửi id, sửa thì gửi id', () {
      expect(const ProductPost(name: 'a', price: 1).toJson().containsKey('id'), false);
      expect(const ProductPost(id: 7, name: 'a', price: 1).toJson()['id'], 7);
    });
  });

  group('Post', () {
    test('createdAt không có hậu tố Z vẫn được hiểu là UTC', () {
      final p = Post.fromJson({'createdAt': '2026-10-20T08:00:00', 'content': 'x', 'userName': 'u'});
      expect(p.createdAt.toUtc(), DateTime.utc(2026, 10, 20, 8));
    });

    test('createdAt có Z được giữ nguyên', () {
      expect(parseServerTime('2026-10-23T01:24:21.18682Z').toUtc().hour, 1);
    });
  });

  test('formatPrice', () {
    expect(formatPrice(10000), '10.000');
    expect(formatPrice(150000), '150.000');
    expect(formatPrice(299000.5), '299.000,5');
    expect(formatPrice(0), '0');
  });
}

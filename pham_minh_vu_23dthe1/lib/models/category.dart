/// Danh mục sản phẩm, trả về từ api/CategoryApi.
class Category {
  final int id;
  final String name;
  final String description;

  const Category({this.id = 0, required this.name, this.description = ''});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  /// Thêm mới (id == 0) không gửi id; sửa thì phải gửi id (controller kiểm tra id URL == id body).
  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'name': name,
        'description': description,
      };
}

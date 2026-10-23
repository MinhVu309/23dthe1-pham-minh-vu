/// Sản phẩm trả về từ api/ProductApi (tương ứng model Product của backend).
class ProductPost {
  final int id;
  final String name;
  final double price;
  final String image;
  final String description;

  /// null = sản phẩm không thuộc danh mục nào
  final int? categoryId;
  final String? categoryName;

  const ProductPost({
    this.id = 0,
    required this.name,
    required this.price,
    this.image = '',
    this.description = '',
    this.categoryId,
    this.categoryName,
  });

  factory ProductPost.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return ProductPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      // price có thể là int hoặc double trong JSON
      price: (json['price'] as num?)?.toDouble() ?? 0,
      image: json['image'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: category is Map ? category['name'] as String? : null,
    );
  }

  /// Khi thêm mới (id == 0) không gửi id để SQL Server tự sinh.
  /// Khi sửa phải gửi id vì controller kiểm tra id trên URL == id trong body.
  /// categoryId luôn được gửi (kể cả null) để có thể bỏ sản phẩm ra khỏi danh mục.
  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'name': name,
        'price': price,
        'image': image,
        'description': description,
        'categoryId': categoryId,
      };
}

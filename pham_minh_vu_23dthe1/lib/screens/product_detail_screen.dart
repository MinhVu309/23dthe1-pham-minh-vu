import 'package:flutter/material.dart';

import '../config/formatters.dart';
import '../models/product_post.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';
import '../widgets/safe_network_image.dart';
import 'product_form_screen.dart';

/// Chi tiết sản phẩm: gọi GET api/ProductApi/{id} rồi hiển thị.
/// Sửa/xóa xong sẽ pop về với thông điệp (String) để danh sách refresh.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.id, this.canEdit = false});

  final int id;

  /// Chỉ Admin được sửa/xóa; User chỉ xem chi tiết.
  final bool canEdit;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductPost> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.getProductById(widget.id);
  }

  Future<void> _edit(ProductPost product) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (message != null && mounted) Navigator.pop(context, message);
  }

  Future<void> _delete(ProductPost product) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa sản phẩm',
      message: 'Bạn có chắc muốn xóa "${product.name}"?',
    );
    if (!ok || !mounted) return;
    try {
      await apiService.deleteProduct(product.id);
      if (mounted) Navigator.pop(context, 'Đã xóa sản phẩm');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, 'Xóa thất bại: ${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductPost>(
      future: _future,
      builder: (context, snapshot) {
        final product = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết sản phẩm'),
            actions: product == null || !widget.canEdit
                ? null
                : [
                    IconButton(
                      tooltip: 'Sửa',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(product),
                    ),
                    IconButton(
                      tooltip: 'Xóa',
                      icon: const Icon(Icons.delete),
                      onPressed: () => _delete(product),
                    ),
                  ],
          ),
          body: _body(context, snapshot),
        );
      },
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<ProductPost> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return ErrorView(
        message: '${snapshot.error}',
        onRetry: () {
          setState(() {
            _future = apiService.getProductById(widget.id);
          });
        },
      );
    }
    final p = snapshot.data!;
    return ListView(
      children: [
        SafeNetworkImage(url: p.image, height: 260, width: double.infinity, fallbackIcon: Icons.image),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${formatPrice(p.price)} VND',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              if (p.categoryName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(p.categoryName!)),
                  ),
                ),
              Text(p.description.isEmpty ? 'Chưa có mô tả' : p.description),
              const SizedBox(height: 8),
              Text('Mã sản phẩm: ${p.id}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

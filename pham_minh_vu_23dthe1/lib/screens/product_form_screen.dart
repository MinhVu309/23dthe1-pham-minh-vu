import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product_post.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';

/// Form thêm (product == null) hoặc sửa sản phẩm.
/// Khi thành công sẽ pop về với thông điệp (String) để màn hình gọi hiện SnackBar và refresh.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final ProductPost? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _image;
  late final TextEditingController _description;
  bool _saving = false;
  int? _categoryId; // null = không thuộc danh mục nào
  late final Future<List<Category>> _categoriesFuture = apiService.getCategories();

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(
      text: p == null ? '' : (p.price == p.price.roundToDouble() ? p.price.toInt().toString() : p.price.toString()),
    );
    _image = TextEditingController(text: p?.image ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _image.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final product = ProductPost(
      id: widget.product?.id ?? 0, // sửa: phải gửi kèm Id trong body
      name: _name.text.trim(),
      price: double.parse(_price.text.trim().replaceAll(',', '.')),
      image: _image.text.trim(),
      description: _description.text.trim(),
      categoryId: _categoryId,
    );
    try {
      if (_isEdit) {
        await apiService.updateProduct(product);
      } else {
        await apiService.addProduct(product);
      }
      if (!mounted) return;
      Navigator.pop(context, _isEdit ? 'Đã cập nhật sản phẩm' : 'Đã thêm sản phẩm');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, '${_isEdit ? 'Sửa' : 'Thêm'} sản phẩm thất bại: ${e.message}', error: true);
    }
  }

  /// Chọn danh mục (kể cả "Không có danh mục"). Không tải được danh sách thì chỉ còn lựa chọn không danh mục.
  Widget _categoryDropdown() {
    return FutureBuilder<List<Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        // Danh mục hiện tại của sản phẩm phải nằm trong danh sách, nếu không Dropdown sẽ báo lỗi
        final value = categories.any((c) => c.id == _categoryId) ? _categoryId : null;
        return DropdownButtonFormField<int?>(
          key: ValueKey('${snapshot.connectionState}-${categories.length}'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Danh mục',
            border: const OutlineInputBorder(),
            helperText: snapshot.hasError ? 'Không tải được danh mục: ${snapshot.error}' : null,
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Không có danh mục')),
            for (final c in categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Giá (VND)', border: OutlineInputBorder()),
              validator: (v) {
                final value = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (value == null) return 'Giá không hợp lệ';
                if (value < 0) return 'Giá không được âm';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _image,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link ảnh (https://...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _categoryDropdown(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm'),
            ),
          ],
        ),
      ),
    );
  }
}

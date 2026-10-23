import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';

/// Admin quản lý danh mục sản phẩm: danh sách, thêm, sửa, xóa (có xác nhận).
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.getCategories();
  }

  // Dùng block {} để closure của setState không trả về Future (Flutter sẽ báo lỗi và không rebuild)
  void _reload() {
    setState(() {
      _future = apiService.getCategories();
    });
  }

  Future<void> _openForm([Category? category]) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryFormDialog(category: category),
    );
    if (message == null || !mounted) return;
    _reload();
    showSnack(context, message);
  }

  Future<void> _delete(Category category) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa danh mục',
      message: 'Xóa danh mục "${category.name}"?\nCác sản phẩm thuộc danh mục này sẽ không còn thuộc danh mục nào.',
    );
    if (!ok || !mounted) return;
    try {
      await apiService.deleteCategory(category.id);
      if (!mounted) return;
      _reload();
      showSnack(context, 'Đã xóa danh mục "${category.name}"');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, 'Xóa thất bại: ${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future.catchError((_) => <Category>[]);
        },
        child: FutureBuilder<List<Category>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: _reload);
            }
            final categories = snapshot.data!;
            if (categories.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 120), Center(child: Text('Chưa có danh mục nào'))],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88), // chừa chỗ cho nút thêm
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = categories[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
                  title: Text(c.name),
                  subtitle: c.description.isEmpty ? null : Text(c.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sửa',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(c),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        icon: const Icon(Icons.delete),
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Hộp thoại thêm (category == null) hoặc sửa danh mục. Thành công thì pop về thông điệp (String).
class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.category});

  final Category? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  bool _saving = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _description = TextEditingController(text: widget.category?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final category = Category(
      id: widget.category?.id ?? 0, // sửa: phải gửi kèm Id trong body
      name: _name.text.trim(),
      description: _description.text.trim(),
    );
    try {
      if (_isEdit) {
        await apiService.updateCategory(category);
      } else {
        await apiService.addCategory(category);
      }
      if (!mounted) return;
      Navigator.pop(context, _isEdit ? 'Đã cập nhật danh mục' : 'Đã thêm danh mục');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, '${_isEdit ? 'Sửa' : 'Thêm'} danh mục thất bại: ${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Sửa danh mục' : 'Thêm danh mục'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên danh mục', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên danh mục' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

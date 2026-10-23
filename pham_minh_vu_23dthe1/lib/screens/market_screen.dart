import 'dart:async';

import 'package:flutter/material.dart';

import '../config/formatters.dart';
import '../models/category.dart';
import '../models/product_post.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';
import '../widgets/logout_button.dart';
import '../widgets/safe_network_image.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

/// Màn hình chợ: danh sách sản phẩm (GET), tìm kiếm có debounce, lọc theo danh mục.
/// Chỉ Admin ([canEdit]) mới thấy nút thêm/sửa/xóa.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, this.canEdit = false, this.embedded = false});

  /// Chỉ Admin được thêm/sửa/xóa sản phẩm; User chỉ xem.
  final bool canEdit;

  /// true khi nằm trong AdminScreen (AdminScreen đã có AppBar riêng).
  final bool embedded;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // Giá trị đặc biệt của bộ lọc: null = tất cả, -1 = chưa thuộc danh mục nào
  static const _uncategorized = -1;

  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<ProductPost>> _future;
  List<Category> _categories = [];
  int? _filter;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Có từ khóa thì gọi API tìm kiếm, không thì lấy toàn bộ danh sách.
  Future<List<ProductPost>> _load() {
    final keyword = _searchController.text.trim();
    return keyword.isEmpty ? apiService.getProducts() : apiService.searchProducts(keyword);
  }

  /// Danh mục dùng cho thanh lọc; lỗi thì bỏ qua (vẫn xem được sản phẩm).
  Future<void> _loadCategories() async {
    try {
      final categories = await apiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        // Danh mục đang lọc đã bị xóa thì bỏ lọc
        if (_filter != null && _filter != _uncategorized && !categories.any((c) => c.id == _filter)) {
          _filter = null;
        }
      });
    } on ApiException {
      // không hiển thị lỗi: thanh lọc chỉ là phần phụ
    }
  }

  // Dùng block {} để closure của setState không trả về Future (Flutter sẽ báo lỗi và không rebuild)
  void _reload() {
    setState(() {
      _future = _load();
    });
    _loadCategories();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    // Đợi người dùng ngừng gõ ~400ms rồi mới gọi API
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _reload();
    });
  }

  /// Mở màn hình khác; nếu trả về thông điệp thì refresh danh sách và báo SnackBar.
  Future<void> _openAndRefresh(Widget screen) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (message == null || !mounted) return;
    _reload();
    showSnack(context, message);
  }

  List<ProductPost> _applyFilter(List<ProductPost> products) {
    if (_filter == null) return products;
    if (_filter == _uncategorized) return products.where((p) => p.categoryId == null).toList();
    return products.where((p) => p.categoryId == _filter).toList();
  }

  Widget _searchBar() {
    return SearchBar(
      controller: _searchController,
      hintText: 'Tìm sản phẩm theo tên...',
      leading: const Icon(Icons.search),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _debounce?.cancel();
                    _reload();
                  },
                ),
        ),
      ],
      onChanged: _onSearchChanged,
      onSubmitted: (_) {
        _debounce?.cancel();
        _reload();
      },
    );
  }

  /// Hàng chip lọc theo danh mục (chỉ hiện khi có danh mục).
  Widget _filterBar() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    Widget chip(String label, int? value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: _filter == value,
            onSelected: (_) => setState(() => _filter = value),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          chip('Tất cả', null),
          for (final c in _categories) chip(c.name, c.id),
          chip('Chưa phân loại', _uncategorized),
        ],
      ),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future.catchError((_) => <ProductPost>[]);
      },
      child: FutureBuilder<List<ProductPost>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _reload);
          }
          final products = _applyFilter(snapshot.data!);
          if (products.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Không có sản phẩm nào')),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = products[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SafeNetworkImage(url: p.image, width: 56, height: 56, fallbackIcon: Icons.image),
                ),
                title: Text(p.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (p.categoryName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          p.categoryName!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Text('${formatPrice(p.price)} VND'),
                // Bấm vào sản phẩm -> màn hình chi tiết sẽ gọi GET api/ProductApi/{id}
                onTap: () => _openAndRefresh(ProductDetailScreen(id: p.id, canEdit: widget.canEdit)),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.embedded
        ? Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: _searchBar()),
              _filterBar(),
              Expanded(child: _list()),
            ],
          )
        : Column(children: [_filterBar(), Expanded(child: _list())]);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('23DTHE1 - Phạm Minh Vũ'),
              actions: const [LogoutButton()],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _searchBar(),
                ),
              ),
            ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              tooltip: 'Thêm sản phẩm',
              onPressed: () => _openAndRefresh(const ProductFormScreen()),
              child: const Icon(Icons.add),
            )
          : null,
      body: body,
    );
  }
}

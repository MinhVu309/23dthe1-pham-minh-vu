import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Khung màn danh sách: tải dữ liệu, hiện loading / lỗi / trống, kéo để làm mới, nút Thêm.
/// Việc thêm/sửa/xoá do màn cụ thể quyết định.
class ResourceListPage<T> extends StatefulWidget {
  const ResourceListPage({
    super.key,
    required this.title,
    required this.load,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
    this.onAdd,
    this.addLabel = 'Thêm',
  });

  final String title;
  final Future<List<T>> Function() load;

  /// `reload` để làm mới danh sách sau khi sửa/xoá.
  final Widget Function(BuildContext context, T item, Future<void> Function() reload) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  /// Mở form thêm; trả `true` nếu đã thêm (để tải lại). `null` = không có nút Thêm.
  final Future<bool> Function(BuildContext context)? onAdd;
  final String addLabel;

  @override
  State<ResourceListPage<T>> createState() => _ResourceListPageState<T>();
}

class _ResourceListPageState<T> extends State<ResourceListPage<T>> {
  List<T>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _items == null;
      _error = null;
    });
    try {
      final items = await widget.load();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items == null) {
      body = ErrorView(message: _error!, onRetry: _reload);
    } else if (_items!.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 80),
        EmptyView(icon: widget.emptyIcon, title: widget.emptyTitle, subtitle: widget.emptySubtitle),
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => widget.itemBuilder(ctx, _items![i], _reload),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: RefreshIndicator(color: AppColors.ink, onRefresh: _reload, child: body),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.ink,
              onPressed: () async {
                if (await widget.onAdd!(context)) await _reload();
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(widget.addLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

/// Khung bottom sheet cho form nhập liệu ngắn (phòng ban, ca).
Future<bool> showFormSheet(BuildContext context, {required WidgetBuilder builder}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(child: builder(ctx)),
    ),
  );
  return saved == true;
}

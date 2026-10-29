/// Dạng trả về `{total, page, pageSize, items}` của các API danh sách.
class PagedResult<T> {
  const PagedResult({required this.items, required this.total, required this.page, required this.pageSize});

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  factory PagedResult.fromJson(dynamic json, T Function(Map<String, dynamic>) parse) {
    final m = (json as Map).cast<String, dynamic>();
    return PagedResult(
      items: (m['items'] as List).map((e) => parse((e as Map).cast<String, dynamic>())).toList(),
      total: (m['total'] as num).toInt(),
      page: (m['page'] as num).toInt(),
      pageSize: (m['pageSize'] as num).toInt(),
    );
  }
}

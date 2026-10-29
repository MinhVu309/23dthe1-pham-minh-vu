import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Một dòng của [StatusCard]: chấm màu, nhãn nhỏ và giá trị đậm.
class StatusRow {
  const StatusRow({required this.color, required this.label, required this.value, this.valueColor});

  final Color color;
  final String label;
  final String value;
  final Color? valueColor;
}

/// Thẻ trắng nổi trên đầu trang, hai dòng nối nhau bằng đường chấm (như thẻ "From / To" trong mẫu),
/// nút làm mới ở bên phải.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.rows, required this.onRefresh, this.loading = false, this.error});

  final List<StatusRow> rows;
  final VoidCallback onRefresh;
  final bool loading;

  /// Có lỗi thì hiện dòng thông báo thay cho các dòng dữ liệu.
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Expanded(
            child: error != null
                ? Row(children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error!, style: const TextStyle(color: AppColors.textMuted, height: 1.3))),
                  ])
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        _row(rows[i]),
                        if (i < rows.length - 1) _connector(),
                      ],
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: loading ? null : onRefresh,
              child: SizedBox(
                width: 46,
                height: 46,
                child: loading
                    ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const Icon(Icons.sync_rounded, color: AppColors.inkSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(StatusRow r) => Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: r.color, width: 3.5)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                Text(r.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: r.valueColor ?? AppColors.ink, fontSize: 16.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );

  /// Đường chấm dọc nối hai chấm tròn.
  Widget _connector() => Padding(
        padding: const EdgeInsets.fromLTRB(7, 2, 0, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(children: List.generate(3, (_) => Container(width: 2, height: 3, margin: const EdgeInsets.symmetric(vertical: 1.2), color: AppColors.paperDeep))),
        ),
      );
}

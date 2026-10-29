import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');
String formatDate(DateTime d) => _dateFmt.format(d);

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2.6)));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, height: 1.4)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: AppColors.paperDeep),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      );
}

/// Thẻ một dòng dữ liệu trong danh sách.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.footer});

  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.paperDeep)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
                          if (subtitle != null) ...[const SizedBox(height: 3), subtitle!],
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                ?footer,
              ],
            ),
          ),
        ),
      );
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color ?? AppColors.ink),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xoá',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
        TextButton(
          style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Chạy một thao tác ghi: thành công thì báo [success], lỗi (kể cả 409) thì hiện thông báo của server.
/// Trả `true` khi thành công. Lỗi 401 đã được ApiClient xử lý (về đăng nhập) nên chỉ cần báo ngắn gọn.
Future<bool> guard(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on ApiException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.danger));
    return false;
  }
}

/// Hàng chip chọn một giá trị để lọc danh sách.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.selected, required this.labelOf, required this.onChanged});

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labelOf(o)),
                  selected: selected == o,
                  selectedColor: AppColors.ink,
                  labelStyle: TextStyle(color: selected == o ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => onChanged(o),
                ),
              ),
          ],
        ),
      );
}

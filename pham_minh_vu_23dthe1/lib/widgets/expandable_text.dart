import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Văn bản dài được rút gọn [maxLines] dòng kèm nút "Xem thêm"; bấm để hiện đủ.
/// Chỉ hiện nút khi nội dung thật sự bị cắt (đo bằng TextPainter).
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.maxLines = 5, this.style});

  final String text;
  final int maxLines;
  final TextStyle? style;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? const TextStyle(fontSize: 15, height: 1.35, color: AppColors.textPrimary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows && !_expanded)
              Semantics(
                button: true,
                label: 'Xem thêm nội dung bài viết',
                child: InkWell(
                  onTap: () => setState(() => _expanded = true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Xem thêm',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

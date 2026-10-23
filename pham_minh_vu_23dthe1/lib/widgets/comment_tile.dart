import 'package:flutter/material.dart';

import '../config/formatters.dart';
import '../models/comment.dart';
import '../theme/app_theme.dart';
import 'app_avatar.dart';

/// Một bình luận: avatar, khung chữ xám bo tròn (tên đậm + nội dung), giờ đăng và nút "Xóa" nếu được phép.
class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment, required this.onDelete});

  final Comment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(url: comment.userAvatar, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(comment.content, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Text(timeAgo(comment.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (comment.canDelete)
                        TextButton(
                          onPressed: onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            minimumSize: const Size(48, 32),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Xóa'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

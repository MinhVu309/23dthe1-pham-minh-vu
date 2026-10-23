import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme/app_theme.dart';
import 'app_avatar.dart';

/// Hàng "Vừa đăng bài": avatar tròn viền xanh của những người có bài mới nhất trong Bảng tin.
/// Đây KHÔNG phải story: chỉ là lối tắt tới trang cá nhân của người vừa đăng, lấy từ các bài đã tải.
class RecentPostersRow extends StatelessWidget {
  const RecentPostersRow({super.key, required this.posts, required this.onOpenProfile, this.max = 15});

  final List<Post> posts;
  final void Function(String userId) onOpenProfile;
  final int max;

  /// Mỗi người một lần, theo thứ tự bài mới nhất; bỏ bài không có chủ (bài mẫu cũ).
  static List<Post> distinctPosters(List<Post> posts, {int max = 15}) {
    final seen = <String>{};
    final result = <Post>[];
    for (final p in posts) {
      final id = p.userId;
      if (id == null || !seen.add(id)) continue;
      result.add(p);
      if (result.length >= max) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final posters = distinctPosters(posts, max: max);
    if (posters.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vừa đăng bài',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: posters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = posters[i];
                return Semantics(
                  button: true,
                  label: 'Trang cá nhân của ${p.userName}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onOpenProfile(p.userId!),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          AppAvatar(url: p.userAvatar, size: 52, ring: true),
                          const SizedBox(height: 4),
                          Text(
                            p.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

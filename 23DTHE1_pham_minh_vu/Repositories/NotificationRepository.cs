using _23DTHE1_pham_minh_vu.Models;
using Microsoft.EntityFrameworkCore;

namespace _23DTHE1_pham_minh_vu.Repositories;

// Thông báo được TÍNH từ bảng PostLike và Comment, không có bảng riêng
public class NotificationRepository : INotificationRepository
{
    private const int SnippetLength = 60;

    private readonly ApplicationDbContext _context;

    public NotificationRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<NotificationDto>> GetForUserAsync(string userId, DateTime since, int max)
    {
        var likes = await _context.PostLikes.AsNoTracking()
            .Where(l => l.Post!.UserId == userId && l.UserId != userId && l.CreatedAt >= since)
            .OrderByDescending(l => l.CreatedAt)
            .Take(max)
            .Select(l => new NotificationDto
            {
                Type = "like",
                PostId = l.PostId,
                PostSnippet = l.Post!.Content,
                ActorId = l.UserId,
                ActorName = l.User != null ? (l.User.DisplayName ?? l.User.UserName) : null,
                ActorAvatar = l.User != null ? l.User.AvatarUrl : null,
                CreatedAt = l.CreatedAt,
            })
            .ToListAsync();

        var comments = await _context.Comments.AsNoTracking()
            .Where(c => c.Post!.UserId == userId && c.UserId != userId && c.CreatedAt >= since)
            .OrderByDescending(c => c.CreatedAt)
            .Take(max)
            .Select(c => new NotificationDto
            {
                Type = "comment",
                PostId = c.PostId,
                PostSnippet = c.Post!.Content,
                ActorId = c.UserId,
                ActorName = c.User != null ? (c.User.DisplayName ?? c.User.UserName) : null,
                ActorAvatar = c.User != null ? c.User.AvatarUrl : null,
                CommentContent = c.Content,
                CreatedAt = c.CreatedAt,
            })
            .ToListAsync();

        // Gộp hai nguồn, mới nhất trước, rồi rút gọn đoạn trích bài viết
        var merged = likes.Concat(comments).OrderByDescending(n => n.CreatedAt).Take(max).ToList();
        foreach (var n in merged)
        {
            if (n.PostSnippet is { Length: > SnippetLength } s)
                n.PostSnippet = s[..SnippetLength] + "…";
        }
        return merged;
    }
}

using _23DTHE1_pham_minh_vu.Models;
using Microsoft.EntityFrameworkCore;

namespace _23DTHE1_pham_minh_vu.Repositories;

public class CommentRepository : ICommentRepository
{
    private readonly ApplicationDbContext _context;

    public CommentRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    // Được xóa: chủ bình luận, chủ bài, hoặc Admin
    private static IQueryable<CommentDto> Project(IQueryable<Comment> comments, string? viewerId, bool viewerIsAdmin)
    {
        return comments.Select(c => new CommentDto
        {
            Id = c.Id,
            PostId = c.PostId,
            UserId = c.UserId,
            UserName = c.User != null ? (c.User.DisplayName ?? c.User.UserName) : null,
            UserAvatar = c.User != null ? c.User.AvatarUrl : null,
            Content = c.Content,
            CreatedAt = c.CreatedAt,
            CanDelete = viewerIsAdmin
                || (viewerId != null && (c.UserId == viewerId || c.Post!.UserId == viewerId)),
        });
    }

    // Cũ nhất trước (đọc từ trên xuống như dưới một bài Facebook)
    public async Task<(IReadOnlyList<CommentDto> Items, int Total)> GetByPostAsync(
        int postId, int page, int pageSize, string? viewerId, bool viewerIsAdmin)
    {
        var query = _context.Comments.AsNoTracking().Where(c => c.PostId == postId);
        var total = await query.CountAsync();
        var items = await Project(
                query.OrderBy(c => c.CreatedAt).ThenBy(c => c.Id).Skip((page - 1) * pageSize).Take(pageSize),
                viewerId, viewerIsAdmin)
            .ToListAsync();
        return (items, total);
    }

    public async Task<CommentDto?> GetDtoAsync(int commentId, string? viewerId, bool viewerIsAdmin)
    {
        return await Project(_context.Comments.AsNoTracking().Where(c => c.Id == commentId), viewerId, viewerIsAdmin)
            .FirstOrDefaultAsync();
    }

    public async Task<Comment?> GetAsync(int postId, int commentId)
    {
        return await _context.Comments
            .Include(c => c.Post)
            .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId);
    }

    public async Task AddAsync(Comment comment)
    {
        comment.CreatedAt = DateTime.UtcNow;
        _context.Comments.Add(comment);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Comment comment)
    {
        _context.Comments.Remove(comment);
        await _context.SaveChangesAsync();
    }
}

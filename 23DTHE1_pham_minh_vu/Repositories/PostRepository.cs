using _23DTHE1_pham_minh_vu.Models;
using Microsoft.EntityFrameworkCore;

namespace _23DTHE1_pham_minh_vu.Repositories;

public class PostRepository : IPostRepository
{
    private readonly ApplicationDbContext _context;

    public PostRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Chuyển Post thành PostDto ngay trong câu truy vấn SQL (đếm like/bình luận bằng subquery, không tải cả danh sách).
    /// - Bài có chủ: trả tên/ảnh HIỆN TẠI theo hồ sơ chủ bài. Bài mẫu cũ (UserId null): dùng tên/ảnh đã lưu.
    /// - likeCount/commentCount = số cũ của bài mẫu + số dòng thật trong PostLike/Comment.
    /// </summary>
    private static IQueryable<PostDto> Project(IQueryable<Post> posts, string? viewerId, bool viewerIsAdmin)
    {
        return posts.Select(p => new PostDto
        {
            Id = p.Id,
            UserId = p.UserId,
            UserName = p.User != null ? (p.User.DisplayName ?? p.User.UserName) : p.UserName,
            UserAvatar = p.User != null ? p.User.AvatarUrl : p.UserAvatar,
            Content = p.Content,
            Image = p.Image,
            CreatedAt = p.CreatedAt,
            LikeCount = p.LikeCount + p.Likes.Count,
            CommentCount = p.CommentCount + p.Comments.Count,
            LikedByMe = viewerId != null && p.Likes.Any(l => l.UserId == viewerId),
            CanEdit = viewerIsAdmin || (viewerId != null && p.UserId == viewerId),
        });
    }

    // Mới nhất trước; Id giảm dần làm khóa phụ để phân trang không bị lặp/mất bài khi trùng giờ
    private static IQueryable<Post> Newest(IQueryable<Post> posts) =>
        posts.OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id);

    public async Task<IReadOnlyList<PostDto>> GetLatestAsync(int max, string? viewerId, bool viewerIsAdmin)
    {
        return await Project(Newest(_context.Posts.AsNoTracking()).Take(max), viewerId, viewerIsAdmin).ToListAsync();
    }

    public async Task<PagedResult<PostDto>> GetPageAsync(
        int page, int pageSize, string? authorId, string? viewerId, bool viewerIsAdmin)
    {
        var query = _context.Posts.AsNoTracking();
        if (authorId != null)
            query = query.Where(p => p.UserId == authorId);

        var total = await query.CountAsync();
        var items = await Project(Newest(query).Skip((page - 1) * pageSize).Take(pageSize), viewerId, viewerIsAdmin)
            .ToListAsync();

        return new PagedResult<PostDto>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalCount = total,
            HasMore = (long)page * pageSize < total,
        };
    }

    public async Task<PostDto?> GetDtoByIdAsync(int id, string? viewerId, bool viewerIsAdmin)
    {
        return await Project(_context.Posts.AsNoTracking().Where(p => p.Id == id), viewerId, viewerIsAdmin)
            .FirstOrDefaultAsync();
    }

    public async Task<int> CountByAuthorAsync(string authorId)
    {
        return await _context.Posts.CountAsync(p => p.UserId == authorId);
    }

    public async Task<Post?> GetByIdAsync(int id)
    {
        return await _context.Posts.FindAsync(id);
    }

    public async Task AddAsync(Post post)
    {
        // Thời gian đăng do server quyết định; like/bình luận cũ luôn bắt đầu từ 0
        post.CreatedAt = DateTime.UtcNow;
        post.LikeCount = 0;
        post.CommentCount = 0;
        _context.Posts.Add(post);
        await _context.SaveChangesAsync();
    }

    // Chỉ đổi nội dung và ảnh; UserId, CreatedAt, like, bình luận được giữ nguyên
    public async Task UpdateContentAsync(Post post, string? content, string? image)
    {
        post.Content = content;
        post.Image = image;
        await _context.SaveChangesAsync();
    }

    // Xóa bài => like và bình luận bị xóa theo (ON DELETE CASCADE trong CSDL)
    public async Task DeleteAsync(Post post)
    {
        _context.Posts.Remove(post);
        await _context.SaveChangesAsync();
    }

    public async Task<(bool Liked, int LikeCount)> ToggleLikeAsync(Post post, string userId)
    {
        var existing = await _context.PostLikes.FindAsync(post.Id, userId);
        bool liked;

        if (existing != null)
        {
            _context.PostLikes.Remove(existing);
            liked = false;
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                // Một request khác vừa bỏ thích rồi: kết quả cuối cùng vẫn là "chưa thích"
                _context.Entry(existing).State = EntityState.Detached;
            }
        }
        else
        {
            var like = new PostLike { PostId = post.Id, UserId = userId, CreatedAt = DateTime.UtcNow };
            _context.PostLikes.Add(like);
            liked = true;
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                // Bấm hai lần cùng lúc: request kia đã thêm dòng (khóa chính trùng) => vẫn là "đã thích"
                _context.Entry(like).State = EntityState.Detached;
            }
        }

        var real = await _context.PostLikes.CountAsync(l => l.PostId == post.Id);
        return (liked, post.LikeCount + real);
    }
}

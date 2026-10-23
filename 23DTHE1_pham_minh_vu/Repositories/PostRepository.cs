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

    // Bài mới nhất hiển thị trước
    public async Task<IEnumerable<Post>> GetPostsAsync()
    {
        return await _context.Posts.OrderByDescending(p => p.CreatedAt).ToListAsync();
    }

    public async Task<Post?> GetPostByIdAsync(int id)
    {
        return await _context.Posts.FindAsync(id);
    }

    public async Task AddPostAsync(Post post)
    {
        // Thời gian đăng do server quyết định, không tin giá trị client gửi lên
        post.CreatedAt = DateTime.UtcNow;
        _context.Posts.Add(post);
        await _context.SaveChangesAsync();
    }

    public async Task UpdatePostAsync(Post post)
    {
        _context.Entry(post).State = EntityState.Modified;
        // Giữ nguyên thời gian đăng ban đầu khi sửa bài
        _context.Entry(post).Property(p => p.CreatedAt).IsModified = false;
        await _context.SaveChangesAsync();
    }

    public async Task DeletePostAsync(int id)
    {
        var post = await _context.Posts.FindAsync(id);
        if (post != null)
        {
            _context.Posts.Remove(post);
            await _context.SaveChangesAsync();
        }
    }
}

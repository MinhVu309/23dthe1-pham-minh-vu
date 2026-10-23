using _23DTHE1_pham_minh_vu.Models;

namespace _23DTHE1_pham_minh_vu.Repositories;

public interface IPostRepository
{
    Task<IEnumerable<Post>> GetPostsAsync();
    Task<Post?> GetPostByIdAsync(int id);
    Task AddPostAsync(Post post);
    Task UpdatePostAsync(Post post);
    Task DeletePostAsync(int id);
}

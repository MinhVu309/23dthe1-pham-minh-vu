using _23DTHE1_pham_minh_vu.Models;

namespace _23DTHE1_pham_minh_vu.Repositories;

public interface IPostRepository
{
    // ----- Đọc (trả DTO đã tính sẵn likeCount, commentCount, likedByMe, canEdit cho người xem) -----
    Task<IReadOnlyList<PostDto>> GetLatestAsync(int max, string? viewerId, bool viewerIsAdmin);
    Task<PagedResult<PostDto>> GetPageAsync(int page, int pageSize, string? authorId, string? viewerId, bool viewerIsAdmin);
    Task<PostDto?> GetDtoByIdAsync(int id, string? viewerId, bool viewerIsAdmin);
    Task<int> CountByAuthorAsync(string authorId);

    // ----- Ghi (làm việc trên thực thể Post) -----
    Task<Post?> GetByIdAsync(int id);
    Task AddAsync(Post post);
    Task UpdateContentAsync(Post post, string? content, string? image);
    Task DeleteAsync(Post post);

    // ----- Thích -----
    Task<(bool Liked, int LikeCount)> ToggleLikeAsync(Post post, string userId);
}

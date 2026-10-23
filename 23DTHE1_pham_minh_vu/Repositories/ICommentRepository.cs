using _23DTHE1_pham_minh_vu.Models;

namespace _23DTHE1_pham_minh_vu.Repositories;

public interface ICommentRepository
{
    Task<(IReadOnlyList<CommentDto> Items, int Total)> GetByPostAsync(
        int postId, int page, int pageSize, string? viewerId, bool viewerIsAdmin);
    Task<CommentDto?> GetDtoAsync(int commentId, string? viewerId, bool viewerIsAdmin);
    Task<Comment?> GetAsync(int postId, int commentId);   // kèm Post để biết chủ bài
    Task AddAsync(Comment comment);
    Task DeleteAsync(Comment comment);
}

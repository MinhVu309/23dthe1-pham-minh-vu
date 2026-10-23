using _23DTHE1_pham_minh_vu.Models;

namespace _23DTHE1_pham_minh_vu.Repositories;

public interface INotificationRepository
{
    /// <summary>Lượt thích và bình luận của NGƯỜI KHÁC trên bài của userId, từ mốc since, mới nhất trước.</summary>
    Task<IReadOnlyList<NotificationDto>> GetForUserAsync(string userId, DateTime since, int max);
}

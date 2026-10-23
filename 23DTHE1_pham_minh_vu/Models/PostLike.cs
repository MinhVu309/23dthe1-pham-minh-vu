namespace _23DTHE1_pham_minh_vu.Models;

// Lượt thích của một người dùng cho một bài đăng. Khóa chính (PostId, UserId) đảm bảo mỗi người chỉ thích một lần.
public class PostLike
{
    public int PostId { get; set; }
    public Post? Post { get; set; }

    public string UserId { get; set; } = string.Empty;
    public User? User { get; set; }

    public DateTime CreatedAt { get; set; }
}

namespace _23DTHE1_pham_minh_vu.Models;

// Bài đăng kiểu Facebook
public class Post
{
    public int Id { get; set; }
    public string? UserName { get; set; }
    public string? UserAvatar { get; set; }
    public string? Content { get; set; }
    public string? Image { get; set; }
    public DateTime CreatedAt { get; set; }
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
}

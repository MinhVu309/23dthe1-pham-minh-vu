using System.ComponentModel.DataAnnotations;

namespace _23DTHE1_pham_minh_vu.Models;

// Bình luận của người dùng trên một bài đăng
public class Comment
{
    public int Id { get; set; }

    public int PostId { get; set; }
    public Post? Post { get; set; }

    public string UserId { get; set; } = string.Empty;
    public User? User { get; set; }

    [MaxLength(500)]
    public string Content { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}

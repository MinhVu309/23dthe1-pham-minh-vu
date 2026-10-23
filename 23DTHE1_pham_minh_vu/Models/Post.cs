namespace _23DTHE1_pham_minh_vu.Models;

// Bài đăng kiểu Facebook
public class Post
{
    public int Id { get; set; }

    // Chủ bài (khóa ngoại tới User). null với bài mẫu cũ: các bài này chỉ Admin mới sửa/xóa được.
    // Server tự gán từ token khi đăng bài, không nhận giá trị client gửi.
    public string? UserId { get; set; }
    public User? User { get; set; }

    // Tên/ảnh đại diện lưu lúc đăng. Bài có UserId thì API trả tên/ảnh HIỆN TẠI của chủ bài (theo hồ sơ);
    // hai cột này chỉ còn dùng cho bài mẫu cũ không có chủ.
    public string? UserName { get; set; }
    public string? UserAvatar { get; set; }
    public string? Content { get; set; }
    public string? Image { get; set; }
    public DateTime CreatedAt { get; set; }
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
}

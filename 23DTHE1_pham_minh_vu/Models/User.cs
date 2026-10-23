using Microsoft.AspNetCore.Identity;

namespace _23DTHE1_pham_minh_vu.Models;

// Người dùng của hệ thống, mở rộng IdentityUser (Id, UserName, Email, PhoneNumber, PasswordHash...)
public class User : IdentityUser
{
    public string? Initials { get; set; }

    // Tên hiển thị trên bài đăng/bình luận (tối đa 50). Tài khoản cũ: mặc định = UserName.
    public string? DisplayName { get; set; }

    // Ảnh đại diện, ảnh bìa (URL, thường là /uploads/... do api/UploadApi trả về), giới thiệu ngắn (tối đa 200)
    public string? AvatarUrl { get; set; }
    public string? CoverUrl { get; set; }
    public string? Bio { get; set; }
}

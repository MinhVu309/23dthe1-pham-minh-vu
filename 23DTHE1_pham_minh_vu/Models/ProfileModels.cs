using System.ComponentModel.DataAnnotations;

namespace _23DTHE1_pham_minh_vu.Models;

// Hồ sơ của chính mình (đầy đủ)
public class MyProfileDto
{
    public string Id { get; set; } = string.Empty;
    public string? UserName { get; set; }
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? DisplayName { get; set; }
    public string? AvatarUrl { get; set; }
    public string? CoverUrl { get; set; }
    public string? Bio { get; set; }
    public string? Initials { get; set; }
    public IList<string> Roles { get; set; } = new List<string>();
    public int PostCount { get; set; }
}

// Hồ sơ công khai: KHÔNG có email, số điện thoại, tên đăng nhập
public class PublicProfileDto
{
    public string Id { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
    public string? AvatarUrl { get; set; }
    public string? CoverUrl { get; set; }
    public string? Bio { get; set; }
    public int PostCount { get; set; }
}

public class ProfileUpdateModel
{
    [Required(ErrorMessage = "Tên hiển thị không được để trống")]
    [MaxLength(50, ErrorMessage = "Tên hiển thị tối đa 50 ký tự")]
    public string DisplayName { get; set; } = string.Empty;

    [HttpUrl(ErrorMessage = "Ảnh đại diện phải là đường dẫn http:// hoặc https:// (tối đa 500 ký tự)")]
    public string? AvatarUrl { get; set; }

    [HttpUrl(ErrorMessage = "Ảnh bìa phải là đường dẫn http:// hoặc https:// (tối đa 500 ký tự)")]
    public string? CoverUrl { get; set; }

    [MaxLength(200, ErrorMessage = "Giới thiệu tối đa 200 ký tự")]
    public string? Bio { get; set; }

    [RegularExpression(@"^[0-9+()\-\s.]{6,20}$", ErrorMessage = "Số điện thoại không hợp lệ")]
    public string? PhoneNumber { get; set; }
}

using System.ComponentModel.DataAnnotations;

namespace _23DTHE1_pham_minh_vu.Models;

public class RegistrationModel
{
    [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập email")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự")]
    public string Password { get; set; } = string.Empty;

    // Chữ viết tắt tên, tối đa 5 ký tự (khớp HasMaxLength(5) của cột Initials)
    [MaxLength(5, ErrorMessage = "Ký tự viết tắt tối đa 5 ký tự")]
    public string? Initials { get; set; }

    // Số điện thoại (không bắt buộc), lưu vào IdentityUser.PhoneNumber
    public string? PhoneNumber { get; set; }

    // Không bắt buộc; chỉ nhận "Admin" hoặc "User", bỏ trống thì mặc định "User"
    public string? Role { get; set; }
}

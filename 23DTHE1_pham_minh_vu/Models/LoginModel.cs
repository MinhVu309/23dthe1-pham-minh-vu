using System.ComponentModel.DataAnnotations;

namespace _23DTHE1_pham_minh_vu.Models;

public class LoginModel
{
    [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
    public string Password { get; set; } = string.Empty;
}

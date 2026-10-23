using Microsoft.AspNetCore.Identity;

namespace _23DTHE1_pham_minh_vu.Models;

// Người dùng của hệ thống, mở rộng IdentityUser (Id, UserName, Email, PhoneNumber, PasswordHash...)
public class User : IdentityUser
{
    public string? Initials { get; set; }
}

using Microsoft.AspNetCore.Identity;

namespace SmartCheck.Api.Models;

public static class Roles
{
    public const string Admin = "Admin";
    public const string Manager = "Manager";
    public const string Employee = "Employee";
}

public class AppUser : IdentityUser
{
    public string FullName { get; set; } = "";
    public string? EmployeeCode { get; set; }
    public int? DepartmentId { get; set; }
    public Department? Department { get; set; }

    /// <summary>Thiết bị đã đăng ký (chống chấm công hộ / máy lạ).</summary>
    public string? DeviceId { get; set; }

    /// <summary>Vector khuôn mặt (JSON mảng float) lúc đăng ký, dùng so khớp ở bước xác thực mặt.</summary>
    public string? FaceEmbeddingJson { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

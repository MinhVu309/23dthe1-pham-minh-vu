using System.ComponentModel.DataAnnotations;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Dtos;

// ---------- Auth ----------
public record RegisterDto([Required, EmailAddress] string Email, [Required, MinLength(6)] string Password, [Required] string FullName);
public record LoginDto([Required] string UserNameOrEmail, [Required] string Password);
public record VerifyOtpDto([Required] string UserNameOrEmail, [Required] string Code, string? DeviceId);
public record ResendOtpDto([Required] string UserNameOrEmail);
public record ForgotPasswordDto([Required] string Email);
public record ResetPasswordDto([Required] string Email, [Required] string Code, [Required, MinLength(6)] string NewPassword);
public record GoogleLoginDto([Required] string IdToken, string? DeviceId);
public record BiometricEnrollDto([Required, MaxLength(200)] string DeviceId);
public record BiometricLoginDto([Required, MaxLength(200)] string DeviceId, [Required] string Token);
public record BiometricEnrollResultDto(string Token, DateTime ExpiresAt);
public record AuthResultDto(string Token, string Role, string UserId, string FullName, string Email);

// ---------- Employees ----------
public record EmployeeCreateDto([Required, EmailAddress] string Email, [Required, MinLength(6)] string Password,
    [Required] string FullName, string? EmployeeCode, int? DepartmentId, string Role = Roles.Employee);
public record EmployeeUpdateDto([Required] string FullName, string? EmployeeCode, int? DepartmentId, string? Role, bool IsActive = true);
public record FaceEnrollDto([Required] float[] Embedding);

// ---------- Leaves ----------
public record LeaveCreateDto(DateOnly FromDate, DateOnly ToDate, [Required] string Reason);
public record LeaveReviewDto(bool Approve);

// ---------- Attendance ----------
public class CheckRequest
{
    [Required] public string QrToken { get; set; } = "";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double Accuracy { get; set; }
    /// <summary>Position.isMocked từ geolocator (Android).</summary>
    public bool IsMocked { get; set; }
    [Required] public string DeviceId { get; set; } = "";
    /// <summary>Client đã qua bước liveness (chớp mắt / quay đầu) bằng ML Kit.</summary>
    public bool FaceVerified { get; set; }
    /// <summary>Vector khuôn mặt do MobileFaceNet tính trên máy (nếu có).</summary>
    public float[]? FaceEmbedding { get; set; }
}

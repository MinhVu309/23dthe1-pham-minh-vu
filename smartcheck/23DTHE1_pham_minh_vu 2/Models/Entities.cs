namespace SmartCheck.Api.Models;

public class Department
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public List<AppUser> Employees { get; set; } = new();
}

/// <summary>Điểm chấm công (văn phòng): toạ độ + bán kính + khoá bí mật để ký QR.</summary>
public class WorkLocation
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string? Address { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int RadiusMeters { get; set; } = 100;
    public int ShiftId { get; set; }
    public Shift? Shift { get; set; }
}

public class Shift
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public TimeSpan StartTime { get; set; } = new(8, 0, 0);
    public TimeSpan EndTime { get; set; } = new(17, 0, 0);
    public int LateToleranceMinutes { get; set; } = 10;
}

public enum LeaveStatus { Pending, Approved, Rejected }

public class LeaveRequest
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public AppUser? User { get; set; }
    public DateOnly FromDate { get; set; }
    public DateOnly ToDate { get; set; }
    public string Reason { get; set; } = "";
    public LeaveStatus Status { get; set; } = LeaveStatus.Pending;
    public string? ReviewedBy { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public enum AttendanceType { CheckIn, CheckOut }

public class Attendance
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public AppUser? User { get; set; }
    public int LocationId { get; set; }
    public WorkLocation? Location { get; set; }
    public AttendanceType Type { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double Accuracy { get; set; }
    public double DistanceMeters { get; set; }
    public bool FaceVerified { get; set; }
    public double? FaceScore { get; set; }
    public bool IsLate { get; set; }
    public bool IsEarlyLeave { get; set; }
}

/// <summary>Cảnh báo gian lận (fake GPS, máy lạ, QR hết hạn...). Admin xem ở trang quản trị.</summary>
public class FraudAlert
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public AppUser? User { get; set; }
    public string Reason { get; set; } = "";
    public string? Detail { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool Resolved { get; set; }
}

public class OtpCode
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public string CodeHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public bool Used { get; set; }
}

/// <summary>
/// Thông tin đăng nhập sinh trắc học của một thiết bị. Sau khi đăng nhập mật khẩu + OTP, app xin một token dài hạn
/// gắn với (người dùng, thiết bị) và cất nó sau vân tay/khuôn mặt của máy. Server chỉ lưu băm của token.
/// </summary>
public class BiometricCredential
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string TokenHash { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
    public DateTime? LastUsedAt { get; set; }
    public bool Revoked { get; set; }
}

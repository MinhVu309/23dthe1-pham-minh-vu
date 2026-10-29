using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Models;
using SmartCheck.Api.Services;

namespace SmartCheck.Api.Data;

/// <summary>
/// Dữ liệu mẫu để demo: 1 quản lý + 5 nhân viên, phòng ban, ca, địa điểm, 3 tuần lịch sử chấm công,
/// đơn nghỉ phép và vài cảnh báo gian lận. CHỈ chạy khi bật <c>Seed:Demo=true</c> (mặc định tắt) và chỉ chạy một lần.
///
/// - Email: nếu email admin là Gmail thì dùng dạng <c>tên+manager@gmail.com</c> (thư OTP vẫn về hộp thư của admin);
///   ngược lại là <c>manager@{domain}</c>. Có thể đặt <c>Seed:DemoEmailBase</c> để chọn địa chỉ gốc khác.
/// - Mật khẩu chung: <c>Seed:DemoPassword</c> (mặc định Demo@123456). Chỉ dùng cho demo.
/// - Mã nhân viên bắt đầu bằng <c>DEMO-</c>. Xoá nhân viên mẫu (Admin → Nhân viên) sẽ xoá luôn lịch sử, đơn nghỉ, cảnh báo của họ.
/// - Chỉ sinh lịch sử cho các ngày đã qua, để vẫn chấm công thật được trong hôm nay.
/// </summary>
public static class DemoSeeder
{
    private record Person(string Key, string Name, string Code, string Department, string Role, double LateChance, int LocationIndex);

    private static readonly Person[] People =
    [
        new("manager", "Trần Quốc Bảo", "DEMO-QL01", "Phòng Kỹ thuật", Roles.Manager, 0.05, 0),
        new("nv01", "Nguyễn Văn An", "DEMO-NV01", "Phòng Kỹ thuật", Roles.Employee, 0.05, 0),
        new("nv02", "Lê Thị Bình", "DEMO-NV02", "Phòng Kế toán", Roles.Employee, 0.35, 0),
        new("nv03", "Phạm Minh Châu", "DEMO-NV03", "Phòng Nhân sự", Roles.Employee, 0.15, 0),
        new("nv04", "Hoàng Gia Dũng", "DEMO-NV04", "Phòng Kinh doanh", Roles.Employee, 0.20, 1),
        new("nv05", "Võ Thanh Hà", "DEMO-NV05", "Phòng Kinh doanh", Roles.Employee, 0.10, 1),
    ];

    private const int HistoryDays = 21;

    public static string EmailFor(string baseEmail, string key)
    {
        var at = baseEmail.LastIndexOf('@');
        var local = baseEmail[..at];
        var domain = baseEmail[(at + 1)..];
        return domain.Equals("gmail.com", StringComparison.OrdinalIgnoreCase)
            ? $"{local.Split('+')[0]}+{key}@{domain}"
            : $"{key}@{domain}";
    }

    public static async Task SeedAsync(IServiceProvider sp, IConfiguration cfg)
    {
        var db = sp.GetRequiredService<AppDbContext>();
        var users = sp.GetRequiredService<UserManager<AppUser>>();
        var log = sp.GetRequiredService<ILoggerFactory>().CreateLogger("DemoSeeder");

        // Giá trị rỗng trong file cấu hình coi như chưa đặt.
        static string? Pick(params string?[] values) => values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));
        var password = Pick(cfg["Seed:DemoPassword"]) ?? "Demo@123456";
        var baseEmail = Pick(cfg["Seed:DemoEmailBase"], cfg["Seed:AdminEmail"]) ?? "admin@smartcheck.local";

        if (await users.FindByEmailAsync(EmailFor(baseEmail, People[0].Key)) is not null)
        {
            log.LogInformation("Dữ liệu mẫu đã có, bỏ qua.");
            return;
        }

        // ---- Danh mục ----
        foreach (var name in new[] { "Phòng Kỹ thuật", "Phòng Kế toán", "Phòng Nhân sự", "Phòng Kinh doanh" })
            if (!await db.Departments.AnyAsync(d => d.Name == name)) db.Departments.Add(new Department { Name = name });
        foreach (var (name, start, end) in new[] { ("Ca sáng", 6, 14), ("Ca chiều", 14, 22) })
            if (!await db.Shifts.AnyAsync(s => s.Name == name))
                db.Shifts.Add(new Shift { Name = name, StartTime = new(start, 0, 0), EndTime = new(end, 0, 0), LateToleranceMinutes = 10 });
        await db.SaveChangesAsync();

        var mainShift = await db.Shifts.OrderBy(s => s.Id).FirstAsync();
        if (!await db.WorkLocations.AnyAsync(l => l.Name == "Chi nhánh Quận 1"))
        {
            db.WorkLocations.Add(new WorkLocation
            {
                Name = "Chi nhánh Quận 1", Address = "Quận 1, TP. Hồ Chí Minh (dữ liệu mẫu)",
                Latitude = 10.7769, Longitude = 106.7009, RadiusMeters = 120, ShiftId = mainShift.Id
            });
            await db.SaveChangesAsync();
        }
        var locations = await db.WorkLocations.Include(l => l.Shift).OrderBy(l => l.Id).ToListAsync();
        var departments = await db.Departments.ToDictionaryAsync(d => d.Name, d => d.Id);

        // ---- Tài khoản ----
        var created = new Dictionary<string, AppUser>();
        foreach (var p in People)
        {
            var email = EmailFor(baseEmail, p.Key);
            var user = new AppUser
            {
                UserName = email, Email = email, EmailConfirmed = true, FullName = p.Name,
                EmployeeCode = p.Code, DepartmentId = departments.GetValueOrDefault(p.Department)
            };
            var res = await users.CreateAsync(user, password);
            if (!res.Succeeded)
            {
                log.LogWarning("Không tạo được tài khoản mẫu {Email}: {Errors}", email, string.Join("; ", res.Errors.Select(e => e.Description)));
                continue;
            }
            await users.AddToRoleAsync(user, p.Role);
            created[p.Key] = user;
        }

        // ---- Lịch sử chấm công: các ngày đã qua, chỉ ngày làm việc ----
        var todayVn = GeoService.ToVietnamTime(DateTime.UtcNow).Date;
        foreach (var p in People.Where(x => x.Role == Roles.Employee))
        {
            if (!created.TryGetValue(p.Key, out var user)) continue;
            var loc = locations[Math.Min(p.LocationIndex, locations.Count - 1)];
            var shift = loc.Shift ?? mainShift;

            for (var back = HistoryDays; back >= 1; back--)
            {
                var day = todayVn.AddDays(-back);
                if (day.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday) continue;
                var rng = new Random(Seed(p.Key, day));
                if (rng.NextDouble() < 0.04) continue; // vắng mặt

                var late = rng.NextDouble() < p.LateChance;
                var inLocal = day + shift.StartTime + (late
                    ? TimeSpan.FromMinutes(shift.LateToleranceMinutes + 1 + rng.Next(0, 30))
                    : TimeSpan.FromMinutes(-rng.Next(0, 20))); // tới sớm tối đa 20 phút, không quá hạn
                var early = rng.NextDouble() < 0.10;
                var outLocal = day + shift.EndTime + (early
                    ? TimeSpan.FromMinutes(-(5 + rng.Next(0, 40)))
                    : TimeSpan.FromMinutes(rng.Next(0, 45)));

                db.Attendances.Add(MakeRecord(user.Id, loc, AttendanceType.CheckIn, inLocal, shift, rng));
                db.Attendances.Add(MakeRecord(user.Id, loc, AttendanceType.CheckOut, outLocal, shift, rng));
            }
        }

        // ---- Đơn nghỉ phép ----
        var manager = created.GetValueOrDefault("manager");
        LeaveRequest Leave(string key, int fromDays, int span, string reason, LeaveStatus status) => new()
        {
            UserId = created[key].Id,
            FromDate = DateOnly.FromDateTime(todayVn.AddDays(fromDays)),
            ToDate = DateOnly.FromDateTime(todayVn.AddDays(fromDays + span)),
            Reason = reason, Status = status,
            ReviewedBy = status == LeaveStatus.Pending ? null : manager?.Id,
            CreatedAt = DateTime.UtcNow.AddDays(Math.Min(fromDays, 0) - 3)
        };
        if (created.ContainsKey("nv01")) db.LeaveRequests.Add(Leave("nv01", -10, 1, "Khám sức khoẻ định kỳ", LeaveStatus.Approved));
        if (created.ContainsKey("nv02")) db.LeaveRequests.Add(Leave("nv02", 3, 2, "Việc gia đình", LeaveStatus.Pending));
        if (created.ContainsKey("nv03")) db.LeaveRequests.Add(Leave("nv03", -4, 0, "Đi du lịch", LeaveStatus.Rejected));
        if (created.ContainsKey("nv04")) db.LeaveRequests.Add(Leave("nv04", 7, 0, "Làm giấy tờ cá nhân", LeaveStatus.Pending));

        // ---- Cảnh báo gian lận mẫu (ghi rõ là dữ liệu mẫu) ----
        void Alert(string key, string reason, string detail, double daysAgo, bool resolved)
        {
            if (!created.TryGetValue(key, out var u)) return;
            db.FraudAlerts.Add(new FraudAlert
            {
                UserId = u.Id, Reason = reason, Detail = $"{detail} (dữ liệu mẫu)",
                CreatedAt = DateTime.UtcNow.AddDays(-daysAgo), Resolved = resolved
            });
        }
        Alert("nv04", "Thiết bị báo vị trí giả lập (mock location)", "lat=10.7769, lng=106.7009, acc=5, device=demo-device-04", 1.2, false);
        Alert("nv05", "Chấm công từ thiết bị chưa đăng ký", "lat=10.7770, lng=106.7010, acc=9, device=demo-device-05b", 0.6, false);
        Alert("nv03", "Di chuyển 4200 m trong 90 s (không thực tế)", "lat=10.8019, lng=106.7144, acc=8, device=demo-device-03", 6, true);

        await db.SaveChangesAsync();
        log.LogInformation("Đã tạo dữ liệu mẫu: {Users} tài khoản (mật khẩu chung theo Seed:DemoPassword), email dạng {Example}.",
            created.Count, EmailFor(baseEmail, "nv01"));
    }

    private static Attendance MakeRecord(string userId, WorkLocation loc, AttendanceType type, DateTime local, Shift shift, Random rng)
    {
        // Toạ độ lệch ngẫu nhiên 5–60 m quanh địa điểm (bán kính cho phép lớn hơn nhiều).
        var meters = 5 + rng.NextDouble() * 55;
        var angle = rng.NextDouble() * Math.PI * 2;
        var lat = loc.Latitude + meters * Math.Cos(angle) / 111_320.0;
        var lng = loc.Longitude + meters * Math.Sin(angle) / (111_320.0 * Math.Cos(loc.Latitude * Math.PI / 180));
        return new Attendance
        {
            UserId = userId, LocationId = loc.Id, Type = type,
            Timestamp = DateTime.SpecifyKind(local.AddHours(-7), DateTimeKind.Utc), // giờ VN -> UTC
            Latitude = Math.Round(lat, 6), Longitude = Math.Round(lng, 6),
            Accuracy = Math.Round(4 + rng.NextDouble() * 11, 1),
            DistanceMeters = Math.Round(GeoService.DistanceMeters(lat, lng, loc.Latitude, loc.Longitude), 1),
            FaceVerified = true,
            // Cùng quy tắc với AttendanceController.
            IsLate = type == AttendanceType.CheckIn && local.TimeOfDay > shift.StartTime + TimeSpan.FromMinutes(shift.LateToleranceMinutes),
            IsEarlyLeave = type == AttendanceType.CheckOut && local.TimeOfDay < shift.EndTime
        };
    }

    /// <summary>Hạt giống ngẫu nhiên ổn định (string.GetHashCode đổi theo từng lần chạy).</summary>
    private static int Seed(string key, DateTime day) => key.Aggregate(17, (h, c) => unchecked(h * 31 + c)) ^ day.DayOfYear ^ (day.Year << 9);
}

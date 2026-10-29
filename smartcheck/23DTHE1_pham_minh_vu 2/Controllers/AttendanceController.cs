using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Dtos;
using SmartCheck.Api.Models;
using SmartCheck.Api.Services;

namespace SmartCheck.Api.Controllers;

[ApiController]
[Route("api/attendance")]
[Authorize]
public class AttendanceController(AppDbContext db, QrTokenService qr, FraudService fraud, IConfiguration cfg) : ControllerBase
{
    private string Uid => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    [HttpPost("check-in")]
    public Task<IActionResult> CheckIn(CheckRequest req) => Process(req, AttendanceType.CheckIn);

    [HttpPost("check-out")]
    public Task<IActionResult> CheckOut(CheckRequest req) => Process(req, AttendanceType.CheckOut);

    /// <summary>Luồng: QR hợp lệ → trong bán kính → chống gian lận → khuôn mặt → ghi công.</summary>
    private async Task<IActionResult> Process(CheckRequest req, AttendanceType type)
    {
        var user = await db.Users.FirstAsync(u => u.Id == Uid);

        // 1) QR
        if (!qr.TryValidate(req.QrToken, out var locationId, out var qrError))
            return BadRequest(new { code = "QR_INVALID", message = qrError });
        var loc = await db.WorkLocations.Include(l => l.Shift).FirstOrDefaultAsync(l => l.Id == locationId);
        if (loc is null) return BadRequest(new { code = "LOCATION_NOT_FOUND", message = "Địa điểm không tồn tại" });

        // 2) Vị trí
        var distance = GeoService.DistanceMeters(req.Latitude, req.Longitude, loc.Latitude, loc.Longitude);
        if (distance > loc.RadiusMeters)
            return BadRequest(new { code = "OUT_OF_RANGE", message = $"Bạn cách điểm chấm công {distance:F0} m (cho phép {loc.RadiusMeters} m)" });

        // 3) Chống fake GPS / máy lạ
        var result = await fraud.EvaluateAsync(user, req);
        if (result.Blocked)
            return StatusCode(403, new { code = "FRAUD_SUSPECTED", message = "Chấm công bị từ chối", reasons = result.BlockReasons });

        // 4) Khuôn mặt
        double? score = null;
        if (!string.IsNullOrEmpty(user.FaceEmbeddingJson))
        {
            if (req.FaceEmbedding is null)
                return BadRequest(new { code = "FACE_REQUIRED", message = "Cần xác thực khuôn mặt" });
            var enrolled = JsonSerializer.Deserialize<float[]>(user.FaceEmbeddingJson)!;
            score = GeoService.Cosine(enrolled, req.FaceEmbedding);
            var threshold = double.Parse(cfg["Face:CosineThreshold"] ?? "0.6");
            if (score < threshold)
            {
                db.FraudAlerts.Add(new FraudAlert { UserId = user.Id, Reason = "Khuôn mặt không khớp", Detail = $"score={score:F3}" });
                await db.SaveChangesAsync();
                return StatusCode(403, new { code = "FACE_MISMATCH", message = "Khuôn mặt không khớp" });
            }
        }
        else if (!req.FaceVerified)
        {
            return BadRequest(new { code = "FACE_REQUIRED", message = "Cần vượt qua bước kiểm tra khuôn mặt (liveness)" });
        }

        // 5) Ghi công (1 vào + 1 ra mỗi ngày)
        var nowUtc = DateTime.UtcNow;
        var local = GeoService.ToVietnamTime(nowUtc);
        var dayStartUtc = local.Date.AddHours(-7);
        var today = await db.Attendances.Where(a => a.UserId == user.Id && a.Timestamp >= dayStartUtc && a.Type == type).AnyAsync();
        if (today) return Conflict(new { code = "ALREADY_DONE", message = type == AttendanceType.CheckIn ? "Hôm nay bạn đã chấm công vào" : "Hôm nay bạn đã chấm công ra" });
        if (type == AttendanceType.CheckOut &&
            !await db.Attendances.AnyAsync(a => a.UserId == user.Id && a.Timestamp >= dayStartUtc && a.Type == AttendanceType.CheckIn))
            return Conflict(new { code = "NO_CHECKIN", message = "Chưa chấm công vào" });

        var shift = loc.Shift;
        var att = new Attendance
        {
            UserId = user.Id, LocationId = loc.Id, Type = type, Timestamp = nowUtc,
            Latitude = req.Latitude, Longitude = req.Longitude, Accuracy = req.Accuracy,
            DistanceMeters = distance, FaceVerified = true, FaceScore = score,
            IsLate = type == AttendanceType.CheckIn && shift != null &&
                     local.TimeOfDay > shift.StartTime + TimeSpan.FromMinutes(shift.LateToleranceMinutes),
            IsEarlyLeave = type == AttendanceType.CheckOut && shift != null && local.TimeOfDay < shift.EndTime
        };
        db.Attendances.Add(att);
        await db.SaveChangesAsync();

        return Ok(new { att.Id, att.Type, timeLocal = new DateTimeOffset(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), TimeSpan.FromHours(7)), att.IsLate, att.IsEarlyLeave, distance = Math.Round(distance), flags = result.FlagReasons });
    }

    /// <summary>Lịch sử chấm công của chính mình.</summary>
    [HttpGet("my")]
    public async Task<IActionResult> My([FromQuery] int days = 30)
    {
        var since = DateTime.UtcNow.AddDays(-Math.Clamp(days, 1, 365));
        var items = await db.Attendances.AsNoTracking().Where(a => a.UserId == Uid && a.Timestamp >= since)
            .OrderByDescending(a => a.Timestamp)
            .Select(a => new { a.Id, a.Type, a.Timestamp, a.IsLate, a.IsEarlyLeave, a.DistanceMeters, location = a.Location!.Name })
            .ToListAsync();
        return Ok(items);
    }

    /// <summary>Admin/Manager: toàn bộ chấm công (bản đồ vị trí, lọc theo ngày/nhân viên).</summary>
    [Authorize(Roles = $"{Roles.Admin},{Roles.Manager}"), HttpGet]
    public async Task<IActionResult> All([FromQuery] string? userId, [FromQuery] DateTime? from, [FromQuery] DateTime? to,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var q = db.Attendances.AsNoTracking().Include(a => a.User).Include(a => a.Location).AsQueryable();
        if (!string.IsNullOrEmpty(userId)) q = q.Where(a => a.UserId == userId);
        if (from.HasValue) q = q.Where(a => a.Timestamp >= from);
        if (to.HasValue) q = q.Where(a => a.Timestamp <= to);
        var total = await q.CountAsync();
        var items = await q.OrderByDescending(a => a.Timestamp).Skip((Math.Max(page, 1) - 1) * pageSize).Take(Math.Clamp(pageSize, 1, 200))
            .Select(a => new { a.Id, a.UserId, userName = a.User!.FullName, a.Type, a.Timestamp, a.Latitude, a.Longitude,
                a.DistanceMeters, a.IsLate, a.IsEarlyLeave, a.FaceScore, location = a.Location!.Name })
            .ToListAsync();
        return Ok(new { total, items });
    }

    /// <summary>Bảng công tháng: số ngày công, số lần đi trễ, về sớm.</summary>
    [HttpGet("report")]
    public async Task<IActionResult> Report([FromQuery] int year, [FromQuery] int month, [FromQuery] string? userId)
    {
        var isReviewer = User.IsInRole(Roles.Admin) || User.IsInRole(Roles.Manager);
        if (!isReviewer) userId = Uid;
        var start = new DateTime(year, month, 1).AddHours(-7);
        var end = new DateTime(year, month, 1).AddMonths(1).AddHours(-7);

        var q = db.Attendances.AsNoTracking().Where(a => a.Timestamp >= start && a.Timestamp < end);
        if (!string.IsNullOrEmpty(userId)) q = q.Where(a => a.UserId == userId);

        var rows = await q.GroupBy(a => new { a.UserId, a.User!.FullName }).Select(g => new
        {
            g.Key.UserId, name = g.Key.FullName,
            daysWorked = g.Count(a => a.Type == AttendanceType.CheckIn),
            lateCount = g.Count(a => a.IsLate),
            earlyLeaveCount = g.Count(a => a.IsEarlyLeave)
        }).ToListAsync();
        return Ok(new { year, month, rows });
    }
}

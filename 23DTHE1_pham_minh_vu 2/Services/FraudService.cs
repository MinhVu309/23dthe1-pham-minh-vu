using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Dtos;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Services;

public record FraudResult(List<string> BlockReasons, List<string> FlagReasons)
{
    public bool Blocked => BlockReasons.Count > 0;
}

/// <summary>Chống fake GPS / chấm công hộ theo nhiều lớp. Mọi vi phạm ghi vào bảng FraudAlerts.</summary>
public class FraudService(AppDbContext db, IConfiguration cfg)
{
    public async Task<FraudResult> EvaluateAsync(AppUser user, CheckRequest req)
    {
        var block = new List<string>();
        var flag = new List<string>();

        // 1) App báo vị trí giả lập (geolocator Position.isMocked)
        if (req.IsMocked) block.Add("Thiết bị báo vị trí giả lập (mock location)");

        // 2) Độ chính xác bất thường
        var maxAcc = double.Parse(cfg["Fraud:MaxAccuracyMeters"] ?? "100");
        if (req.Accuracy <= 0) block.Add("Độ chính xác GPS bằng 0 (dấu hiệu giả lập)");
        else if (req.Accuracy > maxAcc) block.Add($"Độ chính xác GPS quá kém ({req.Accuracy:F0} m)");

        // 3) Thiết bị: gắn máy ở lần chấm công đầu tiên, máy khác bị chặn
        if (string.IsNullOrEmpty(user.DeviceId)) { user.DeviceId = req.DeviceId; await db.SaveChangesAsync(); }
        else if (user.DeviceId != req.DeviceId) block.Add("Chấm công từ thiết bị chưa đăng ký");

        // 4) Tốc độ di chuyển phi thực tế so với lần chấm công trước
        var prev = await db.Attendances.Where(a => a.UserId == user.Id)
            .OrderByDescending(a => a.Timestamp).FirstOrDefaultAsync();
        if (prev is not null)
        {
            var seconds = (DateTime.UtcNow - prev.Timestamp).TotalSeconds;
            var meters = GeoService.DistanceMeters(prev.Latitude, prev.Longitude, req.Latitude, req.Longitude);
            if (seconds > 0 && seconds < 3600 && meters / seconds > 60) // > 216 km/h
                block.Add($"Di chuyển {meters:F0} m trong {seconds:F0} s (không thực tế)");
        }

        // 5) Nhiều người cùng toạ độ y hệt trong 2 phút (chỉ gắn cờ)
        var since = DateTime.UtcNow.AddMinutes(-2);
        var same = await db.Attendances.AnyAsync(a => a.UserId != user.Id && a.Timestamp > since &&
            a.Latitude == req.Latitude && a.Longitude == req.Longitude);
        if (same) flag.Add("Trùng toạ độ y hệt với nhân viên khác");

        foreach (var r in block.Concat(flag))
            db.FraudAlerts.Add(new FraudAlert { UserId = user.Id, Reason = r,
                Detail = $"lat={req.Latitude}, lng={req.Longitude}, acc={req.Accuracy}, device={req.DeviceId}" });
        if (block.Count + flag.Count > 0) await db.SaveChangesAsync();

        return new FraudResult(block, flag);
    }
}

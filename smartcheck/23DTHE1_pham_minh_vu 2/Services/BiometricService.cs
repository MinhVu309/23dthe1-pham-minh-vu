using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Services;

/// <summary>
/// Token đăng nhập sinh trắc học: chuỗi ngẫu nhiên 256 bit, gắn với (người dùng, thiết bị), mặc định sống 30 ngày.
/// Server chỉ giữ băm SHA-256 nên lộ DB cũng không dùng lại được token. Mỗi thiết bị chỉ có một token còn hiệu lực.
/// </summary>
public class BiometricService(AppDbContext db, IConfiguration cfg)
{
    private int Days => int.TryParse(cfg["Biometric:TokenDays"], out var d) && d > 0 ? d : 30;

    private static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    /// <summary>Cấp token mới cho thiết bị này, thu hồi token cũ của cùng (người dùng, thiết bị).</summary>
    public async Task<(string Token, DateTime ExpiresAt)> EnrollAsync(string userId, string deviceId)
    {
        await RevokeAsync(userId, deviceId);
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).Replace('+', '-').Replace('/', '_').TrimEnd('=');
        var expires = DateTime.UtcNow.AddDays(Days);
        db.BiometricCredentials.Add(new BiometricCredential
        {
            UserId = userId, DeviceId = deviceId, TokenHash = Hash(token), ExpiresAt = expires
        });
        await db.SaveChangesAsync();
        return (token, expires);
    }

    /// <summary>Trả user id nếu token đúng, đúng thiết bị, chưa hết hạn và chưa bị thu hồi; ngược lại null.</summary>
    public async Task<string?> ValidateAsync(string deviceId, string token)
    {
        var hash = Hash(token.Trim());
        var cred = await db.BiometricCredentials.FirstOrDefaultAsync(c => c.TokenHash == hash);
        if (cred is null || cred.Revoked || cred.ExpiresAt < DateTime.UtcNow || cred.DeviceId != deviceId) return null;
        cred.LastUsedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return cred.UserId;
    }

    public async Task RevokeAsync(string userId, string? deviceId = null)
    {
        var q = db.BiometricCredentials.Where(c => c.UserId == userId && !c.Revoked);
        if (deviceId is not null) q = q.Where(c => c.DeviceId == deviceId);
        foreach (var c in await q.ToListAsync()) c.Revoked = true;
        await db.SaveChangesAsync();
    }
}

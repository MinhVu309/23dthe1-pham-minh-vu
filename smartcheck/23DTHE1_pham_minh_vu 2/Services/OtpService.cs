using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Services;

public class OtpService(AppDbContext db, EmailService mail)
{
    private const int MaxAttempts = 5;

    private static string Hash(string userId, string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{userId}:{code}")));

    public async Task SendAsync(AppUser user)
    {
        var old = await db.OtpCodes.Where(o => o.UserId == user.Id).ToListAsync();
        db.OtpCodes.RemoveRange(old);

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        db.OtpCodes.Add(new OtpCode
        {
            UserId = user.Id,
            CodeHash = Hash(user.Id, code),
            ExpiresAt = DateTime.UtcNow.AddMinutes(5)
        });
        await db.SaveChangesAsync();

        // Tài khoản chưa xác minh email (vừa đăng ký): mã này dùng để xác minh, không phải để đăng nhập.
        if (user.EmailConfirmed)
            await mail.SendAsync(user.Email!, "Mã OTP đăng nhập SmartCheck",
                $"Mã OTP của bạn là {code}. Mã có hiệu lực 5 phút, không chia sẻ cho bất kỳ ai.");
        else
            await mail.SendAsync(user.Email!, "Mã xác minh email SmartCheck",
                $"Mã xác minh email của bạn là {code}. Nhập mã này trong ứng dụng để hoàn tất đăng ký. Mã có hiệu lực 5 phút, không chia sẻ cho bất kỳ ai.");
    }

    public async Task<bool> VerifyAsync(AppUser user, string code)
    {
        var otp = await db.OtpCodes.FirstOrDefaultAsync(o => o.UserId == user.Id && !o.Used);
        if (otp is null || otp.ExpiresAt < DateTime.UtcNow || otp.Attempts >= MaxAttempts) return false;

        otp.Attempts++;
        var ok = CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(otp.CodeHash), Encoding.UTF8.GetBytes(Hash(user.Id, code.Trim())));
        if (ok) otp.Used = true;
        await db.SaveChangesAsync();
        return ok;
    }
}

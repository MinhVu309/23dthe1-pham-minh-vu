using System.Security.Cryptography;
using System.Text;

namespace SmartCheck.Api.Services;

/// <summary>
/// QR động: token = SC1.{locationId}.{expUnix}.{HMAC-SHA256 base64url}.
/// App hiện QR đổi mỗi ~30s; token hết hạn sau Qr:TtlSeconds nên ảnh chụp QR không dùng lại được.
/// </summary>
public class QrTokenService(IConfiguration cfg)
{
    public int TtlSeconds => int.Parse(cfg["Qr:TtlSeconds"] ?? "45");
    private byte[] Key => Encoding.UTF8.GetBytes(cfg["Qr:Secret"]!);

    private string Sign(string payload) =>
        Base64Url(HMACSHA256.HashData(Key, Encoding.UTF8.GetBytes(payload)));

    private static string Base64Url(byte[] data) =>
        Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public string Create(int locationId)
    {
        var exp = DateTimeOffset.UtcNow.AddSeconds(TtlSeconds).ToUnixTimeSeconds();
        var payload = $"{locationId}.{exp}";
        return $"SC1.{payload}.{Sign(payload)}";
    }

    public bool TryValidate(string token, out int locationId, out string error)
    {
        locationId = 0; error = "";
        var parts = token.Split('.');
        if (parts.Length != 4 || parts[0] != "SC1") { error = "QR không hợp lệ"; return false; }

        var payload = $"{parts[1]}.{parts[2]}";
        var expected = Encoding.UTF8.GetBytes(Sign(payload));
        if (!CryptographicOperations.FixedTimeEquals(expected, Encoding.UTF8.GetBytes(parts[3])))
        { error = "Chữ ký QR sai"; return false; }

        if (!int.TryParse(parts[1], out locationId) || !long.TryParse(parts[2], out var exp))
        { error = "QR không hợp lệ"; return false; }

        if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() > exp) { error = "QR đã hết hạn, hãy quét lại"; return false; }
        return true;
    }
}

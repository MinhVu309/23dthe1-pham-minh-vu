using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartCheck.Api.Data;
using SmartCheck.Api.Models;
using SmartCheck.Api.Services;

namespace SmartCheck.Api.Controllers;

[ApiController]
[Route("api/qr")]
[Authorize(Roles = $"{Roles.Admin},{Roles.Manager}")]
public class QrController(QrTokenService qr, AppDbContext db) : ControllerBase
{
    /// <summary>Màn hình "Điểm chấm công" gọi mỗi ~30s để lấy QR mới.</summary>
    [HttpGet("current")]
    public async Task<IActionResult> Current([FromQuery] int locationId)
    {
        var loc = await db.WorkLocations.FindAsync(locationId);
        if (loc is null) return NotFound(new { message = "Không có địa điểm" });
        return Ok(new { token = qr.Create(locationId), ttlSeconds = qr.TtlSeconds, location = loc.Name });
    }
}

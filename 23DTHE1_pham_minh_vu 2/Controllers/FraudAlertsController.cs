using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Controllers;

[ApiController]
[Route("api/fraud-alerts")]
[Authorize(Roles = $"{Roles.Admin},{Roles.Manager}")]
public class FraudAlertsController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] bool? resolved)
    {
        var q = db.FraudAlerts.AsNoTracking().Include(f => f.User).AsQueryable();
        if (resolved.HasValue) q = q.Where(f => f.Resolved == resolved);
        var items = await q.OrderByDescending(f => f.CreatedAt).Take(200)
            .Select(f => new { f.Id, f.UserId, userName = f.User!.FullName, f.Reason, f.Detail, f.CreatedAt, f.Resolved })
            .ToListAsync();
        return Ok(items);
    }

    [HttpPost("{id:int}/resolve")]
    public async Task<IActionResult> Resolve(int id)
    {
        var f = await db.FraudAlerts.FindAsync(id);
        if (f is null) return NotFound();
        f.Resolved = true;
        await db.SaveChangesAsync();
        return NoContent();
    }

    [Authorize(Roles = Roles.Admin), HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var f = await db.FraudAlerts.FindAsync(id);
        if (f is null) return NotFound();
        db.FraudAlerts.Remove(f);
        await db.SaveChangesAsync();
        return NoContent();
    }
}

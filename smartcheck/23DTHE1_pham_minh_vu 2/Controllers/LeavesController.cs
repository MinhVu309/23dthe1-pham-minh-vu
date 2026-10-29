using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Dtos;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Controllers;

[ApiController]
[Route("api/leaves")]
[Authorize]
public class LeavesController(AppDbContext db) : ControllerBase
{
    private string Uid => User.FindFirstValue(ClaimTypes.NameIdentifier)!;
    private bool IsReviewer => User.IsInRole(Roles.Admin) || User.IsInRole(Roles.Manager);

    /// <summary>Nhân viên xem đơn của mình; Admin/Manager xem tất cả (lọc theo status).</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] LeaveStatus? status)
    {
        var q = db.LeaveRequests.AsNoTracking().Include(l => l.User).AsQueryable();
        if (!IsReviewer) q = q.Where(l => l.UserId == Uid);
        if (status.HasValue) q = q.Where(l => l.Status == status);
        var items = await q.OrderByDescending(l => l.CreatedAt)
            .Select(l => new { l.Id, l.UserId, userName = l.User!.FullName, l.FromDate, l.ToDate, l.Reason, l.Status, l.CreatedAt })
            .ToListAsync();
        return Ok(items);
    }

    [HttpPost]
    public async Task<IActionResult> Create(LeaveCreateDto dto)
    {
        if (dto.ToDate < dto.FromDate) return BadRequest(new { message = "Ngày kết thúc phải sau ngày bắt đầu" });
        var l = new LeaveRequest { UserId = Uid, FromDate = dto.FromDate, ToDate = dto.ToDate, Reason = dto.Reason };
        db.LeaveRequests.Add(l);
        await db.SaveChangesAsync();
        return Created($"api/leaves/{l.Id}", new { l.Id });
    }

    /// <summary>Chủ đơn sửa khi còn Pending.</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, LeaveCreateDto dto)
    {
        var l = await db.LeaveRequests.FindAsync(id);
        if (l is null || l.UserId != Uid) return NotFound();
        if (l.Status != LeaveStatus.Pending) return Conflict(new { message = "Đơn đã được duyệt/từ chối" });
        l.FromDate = dto.FromDate; l.ToDate = dto.ToDate; l.Reason = dto.Reason;
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var l = await db.LeaveRequests.FindAsync(id);
        if (l is null || (l.UserId != Uid && !User.IsInRole(Roles.Admin))) return NotFound();
        if (l.Status != LeaveStatus.Pending && !User.IsInRole(Roles.Admin)) return Conflict(new { message = "Đơn đã xử lý" });
        db.LeaveRequests.Remove(l);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [Authorize(Roles = $"{Roles.Admin},{Roles.Manager}"), HttpPost("{id:int}/review")]
    public async Task<IActionResult> Review(int id, LeaveReviewDto dto)
    {
        var l = await db.LeaveRequests.FindAsync(id);
        if (l is null) return NotFound();
        l.Status = dto.Approve ? LeaveStatus.Approved : LeaveStatus.Rejected;
        l.ReviewedBy = Uid;
        await db.SaveChangesAsync();
        return NoContent();
    }
}

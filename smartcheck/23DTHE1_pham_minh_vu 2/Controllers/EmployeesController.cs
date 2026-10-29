using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Dtos;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Controllers;

[ApiController]
[Route("api/employees")]
[Authorize(Roles = $"{Roles.Admin},{Roles.Manager}")]
public class EmployeesController(UserManager<AppUser> users) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? q, [FromQuery] int? departmentId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 100);
        var query = users.Users.AsNoTracking().Include(u => u.Department).AsQueryable();
        if (!string.IsNullOrWhiteSpace(q))
            query = query.Where(u => u.FullName.Contains(q) || u.Email!.Contains(q) || u.EmployeeCode!.Contains(q));
        if (departmentId.HasValue) query = query.Where(u => u.DepartmentId == departmentId);

        var total = await query.CountAsync();
        var items = await query.OrderBy(u => u.FullName).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(u => new { u.Id, u.FullName, u.Email, u.EmployeeCode, u.DepartmentId,
                department = u.Department != null ? u.Department.Name : null, u.IsActive,
                hasFace = u.FaceEmbeddingJson != null }).ToListAsync();
        return Ok(new { total, page, pageSize, items });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(string id)
    {
        var u = await users.FindByIdAsync(id);
        if (u is null) return NotFound();
        var roles = await users.GetRolesAsync(u);
        return Ok(new { u.Id, u.FullName, u.Email, u.EmployeeCode, u.DepartmentId, u.IsActive, role = roles.FirstOrDefault() });
    }

    [Authorize(Roles = Roles.Admin), HttpPost]
    public async Task<IActionResult> Create(EmployeeCreateDto dto)
    {
        if (dto.Role is not (Roles.Admin or Roles.Manager or Roles.Employee)) return BadRequest(new { message = "Role không hợp lệ" });
        var u = new AppUser { UserName = dto.Email, Email = dto.Email, EmailConfirmed = true, FullName = dto.FullName,
            EmployeeCode = dto.EmployeeCode, DepartmentId = dto.DepartmentId };
        var r = await users.CreateAsync(u, dto.Password);
        if (!r.Succeeded) return BadRequest(new { errors = r.Errors.Select(e => e.Description) });
        await users.AddToRoleAsync(u, dto.Role);
        return CreatedAtAction(nameof(Get), new { id = u.Id }, new { u.Id, u.FullName, u.Email });
    }

    [Authorize(Roles = Roles.Admin), HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, EmployeeUpdateDto dto)
    {
        var u = await users.FindByIdAsync(id);
        if (u is null) return NotFound();
        u.FullName = dto.FullName; u.EmployeeCode = dto.EmployeeCode; u.DepartmentId = dto.DepartmentId; u.IsActive = dto.IsActive;
        await users.UpdateAsync(u);

        if (dto.Role is Roles.Admin or Roles.Manager or Roles.Employee)
        {
            var current = await users.GetRolesAsync(u);
            if (!current.Contains(dto.Role))
            {
                await users.RemoveFromRolesAsync(u, current);
                await users.AddToRoleAsync(u, dto.Role);
            }
        }
        return NoContent();
    }

    [Authorize(Roles = Roles.Admin), HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var u = await users.FindByIdAsync(id);
        if (u is null) return NotFound();
        await users.DeleteAsync(u);
        return NoContent();
    }

    /// <summary>Đăng ký khuôn mặt (vector MobileFaceNet) cho nhân viên.</summary>
    [HttpPut("{id}/face")]
    public async Task<IActionResult> EnrollFace(string id, FaceEnrollDto dto)
    {
        var u = await users.FindByIdAsync(id);
        if (u is null) return NotFound();
        u.FaceEmbeddingJson = JsonSerializer.Serialize(dto.Embedding);
        await users.UpdateAsync(u);
        return NoContent();
    }

    /// <summary>Reset thiết bị đã gắn (khi nhân viên đổi máy).</summary>
    [Authorize(Roles = Roles.Admin), HttpPost("{id}/reset-device")]
    public async Task<IActionResult> ResetDevice(string id)
    {
        var u = await users.FindByIdAsync(id);
        if (u is null) return NotFound();
        u.DeviceId = null;
        await users.UpdateAsync(u);
        return NoContent();
    }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Data;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Controllers;

/// <summary>CRUD dùng chung: ai đăng nhập cũng được đọc, chỉ Admin được ghi.</summary>
[ApiController]
public abstract class CrudController<T>(AppDbContext db) : ControllerBase where T : class
{
    protected abstract DbSet<T> Set { get; }
    protected AppDbContext Db => db;

    [Authorize, HttpGet]
    public virtual async Task<IActionResult> GetAll([FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 200);
        var total = await Set.CountAsync();
        var items = await Set.AsNoTracking().Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        return Ok(new { total, page, pageSize, items });
    }

    [Authorize, HttpGet("{id:int}")]
    public virtual async Task<IActionResult> Get(int id)
    {
        var e = await Set.FindAsync(id);
        return e is null ? NotFound() : Ok(e);
    }

    [Authorize(Roles = Roles.Admin), HttpPost]
    public virtual async Task<IActionResult> Create(T input)
    {
        typeof(T).GetProperty("Id")!.SetValue(input, 0);
        Set.Add(input);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = typeof(T).GetProperty("Id")!.GetValue(input) }, input);
    }

    [Authorize(Roles = Roles.Admin), HttpPut("{id:int}")]
    public virtual async Task<IActionResult> Update(int id, T input)
    {
        var existing = await Set.FindAsync(id);
        if (existing is null) return NotFound();
        typeof(T).GetProperty("Id")!.SetValue(input, id);
        db.Entry(existing).CurrentValues.SetValues(input);
        await db.SaveChangesAsync();
        return Ok(existing);
    }

    [Authorize(Roles = Roles.Admin), HttpDelete("{id:int}")]
    public virtual async Task<IActionResult> Delete(int id)
    {
        var e = await Set.FindAsync(id);
        if (e is null) return NotFound();
        Set.Remove(e);
        try { await db.SaveChangesAsync(); }
        catch (DbUpdateException) { return Conflict(new { message = "Đang được sử dụng, không thể xoá" }); }
        return NoContent();
    }
}

[Route("api/departments")]
public class DepartmentsController(AppDbContext db) : CrudController<Department>(db)
{
    protected override DbSet<Department> Set => Db.Departments;
}

[Route("api/shifts")]
public class ShiftsController(AppDbContext db) : CrudController<Shift>(db)
{
    protected override DbSet<Shift> Set => Db.Shifts;
}

[Route("api/locations")]
public class LocationsController(AppDbContext db) : CrudController<WorkLocation>(db)
{
    protected override DbSet<WorkLocation> Set => Db.WorkLocations;
}

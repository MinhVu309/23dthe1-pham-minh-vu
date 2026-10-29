using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(IServiceProvider sp, IConfiguration cfg)
    {
        var db = sp.GetRequiredService<AppDbContext>();
        var roleMgr = sp.GetRequiredService<RoleManager<IdentityRole>>();
        var userMgr = sp.GetRequiredService<UserManager<AppUser>>();

        foreach (var r in new[] { Roles.Admin, Roles.Manager, Roles.Employee })
            if (!await roleMgr.RoleExistsAsync(r)) await roleMgr.CreateAsync(new IdentityRole(r));

        var email = cfg["Seed:AdminEmail"] ?? "admin@smartcheck.local";
        if (await userMgr.FindByEmailAsync(email) is null)
        {
            var admin = new AppUser { UserName = email, Email = email, EmailConfirmed = true, FullName = "Quản trị viên" };
            var res = await userMgr.CreateAsync(admin, cfg["Seed:AdminPassword"] ?? "Admin@123456");
            if (res.Succeeded) await userMgr.AddToRoleAsync(admin, Roles.Admin);
        }

        if (!await db.Shifts.AnyAsync())
        {
            var shift = new Shift { Name = "Ca hành chính", StartTime = new(8, 0, 0), EndTime = new(17, 0, 0), LateToleranceMinutes = 10 };
            db.Shifts.Add(shift);
            await db.SaveChangesAsync();
            // Toạ độ mẫu (TP.HCM) — ĐỔI lại theo văn phòng thật trong trang quản trị.
            db.WorkLocations.Add(new WorkLocation { Name = "Văn phòng chính", Address = "TP. Hồ Chí Minh",
                Latitude = 10.8019, Longitude = 106.7144, RadiusMeters = 150, ShiftId = shift.Id });
            db.Departments.Add(new Department { Name = "Phòng Kỹ thuật" });
            await db.SaveChangesAsync();
        }
    }
}

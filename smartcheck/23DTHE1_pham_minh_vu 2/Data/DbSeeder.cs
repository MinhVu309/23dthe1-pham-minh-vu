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

        // Đổi mật khẩu Admin đã có sẵn trong DB: seeder ở trên chỉ tạo Admin khi chưa có nên sửa Seed:AdminPassword
        // một mình không đủ. Bật Seed:SyncAdminPassword=true thì mỗi lần khởi động mật khẩu Admin được đặt theo cấu hình
        // (chỉ đổi khi khác). Đổi xong có thể tắt công tắc.
        if (cfg.GetValue<bool>("Seed:SyncAdminPassword") && !string.IsNullOrWhiteSpace(cfg["Seed:AdminPassword"]))
        {
            var current = await userMgr.FindByEmailAsync(email);
            var wanted = cfg["Seed:AdminPassword"]!;
            var log = sp.GetRequiredService<ILoggerFactory>().CreateLogger("DbSeeder");
            if (current is not null && !await userMgr.CheckPasswordAsync(current, wanted))
            {
                var reset = await userMgr.ResetPasswordAsync(current, await userMgr.GeneratePasswordResetTokenAsync(current), wanted);
                if (reset.Succeeded) log.LogWarning("Đã đổi mật khẩu Admin {Email} theo Seed:AdminPassword.", email);
                else log.LogError("Không đổi được mật khẩu Admin: {Errors}", string.Join("; ", reset.Errors.Select(e => e.Description)));
            }
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

        // Dữ liệu mẫu để demo: mặc định TẮT. Bật bằng Seed:Demo=true (hoặc biến môi trường Seed__Demo=true).
        if (cfg.GetValue<bool>("Seed:Demo")) await DemoSeeder.SeedAsync(sp, cfg);
    }
}

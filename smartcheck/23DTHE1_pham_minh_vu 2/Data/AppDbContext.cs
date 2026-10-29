using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Models;

namespace SmartCheck.Api.Data;

public class AppDbContext : IdentityDbContext<AppUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Department> Departments => Set<Department>();
    public DbSet<WorkLocation> WorkLocations => Set<WorkLocation>();
    public DbSet<Shift> Shifts => Set<Shift>();
    public DbSet<LeaveRequest> LeaveRequests => Set<LeaveRequest>();
    public DbSet<Attendance> Attendances => Set<Attendance>();
    public DbSet<FraudAlert> FraudAlerts => Set<FraudAlert>();
    public DbSet<OtpCode> OtpCodes => Set<OtpCode>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);
        b.Entity<AppUser>().HasOne(u => u.Department).WithMany(d => d.Employees)
            .HasForeignKey(u => u.DepartmentId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<Attendance>().HasIndex(a => new { a.UserId, a.Timestamp });
        b.Entity<Attendance>().HasOne(a => a.User).WithMany().HasForeignKey(a => a.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        b.Entity<Attendance>().HasOne(a => a.Location).WithMany().HasForeignKey(a => a.LocationId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<FraudAlert>().HasOne(f => f.User).WithMany().HasForeignKey(f => f.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        b.Entity<LeaveRequest>().HasOne(l => l.User).WithMany().HasForeignKey(l => l.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

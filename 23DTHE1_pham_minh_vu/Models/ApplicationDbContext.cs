using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace _23DTHE1_pham_minh_vu.Models;

public class ApplicationDbContext : IdentityDbContext<User>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    public DbSet<Product> Products { get; set; }
    public DbSet<Post> Posts { get; set; }
    public DbSet<Category> Categories { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Bắt buộc gọi base để Identity cấu hình các bảng AspNetUsers, AspNetRoles...
        base.OnModelCreating(modelBuilder);

        // Toàn bộ bảng (kể cả Products, Posts) nằm trong schema "identity" thay vì "dbo"
        modelBuilder.HasDefaultSchema("identity");
        modelBuilder.Entity<User>().Property(u => u.Initials).HasMaxLength(5);

        // Xóa danh mục thì CategoryId của các sản phẩm thuộc danh mục đó về NULL (không xóa sản phẩm)
        modelBuilder.Entity<Product>()
            .HasOne(p => p.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(p => p.CategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        // Dữ liệu mẫu cho bài đăng (HasData cần giá trị cố định, nên CreatedAt ghi cứng và phải nằm trong quá khứ)
        const string img = "https://flutter.github.io/assets-for-api-docs/assets/widgets/";
        modelBuilder.Entity<Post>().HasData(
            new Post
            {
                Id = 1, UserName = "Phạm Minh Vũ", UserAvatar = img + "owl.jpg",
                Content = "Hôm nay mình hoàn thành bài Tuần 6 môn Lập trình thiết bị di động!",
                Image = img + "owl-2.jpg", CreatedAt = new DateTime(2026, 10, 19, 8, 0, 0, DateTimeKind.Utc),
                LikeCount = 12, CommentCount = 3
            },
            new Post
            {
                Id = 2, UserName = "Nguyễn Văn A", UserAvatar = img + "owl-2.jpg",
                Content = "Flutter gọi API ASP.NET Core khá dễ, chỉ cần nhớ 10.0.2.2 khi chạy trên Android emulator.",
                Image = img + "falcon.jpg", CreatedAt = new DateTime(2026, 10, 19, 9, 30, 0, DateTimeKind.Utc),
                LikeCount = 8, CommentCount = 1
            },
            new Post
            {
                Id = 3, UserName = "Trần Thị B", UserAvatar = img + "falcon.jpg",
                Content = "Ai có tài liệu về Repository Pattern chia sẻ mình với nhé.",
                Image = null, CreatedAt = new DateTime(2026, 10, 20, 14, 15, 0, DateTimeKind.Utc),
                LikeCount = 5, CommentCount = 7
            },
            new Post
            {
                Id = 4, UserName = "Lê Văn C", UserAvatar = img + "owl.jpg",
                Content = "Cuối tuần này cả nhóm cà phê và ôn thi nhé!",
                Image = img + "owl.jpg", CreatedAt = new DateTime(2026, 10, 21, 19, 0, 0, DateTimeKind.Utc),
                LikeCount = 21, CommentCount = 9
            },
            new Post
            {
                Id = 5, UserName = "Hoàng Thị D", UserAvatar = img + "owl-2.jpg",
                Content = "Mới học xong phần CRUD với Entity Framework Core, cảm giác rất đã.",
                Image = img + "falcon.jpg", CreatedAt = new DateTime(2026, 10, 22, 7, 45, 0, DateTimeKind.Utc),
                LikeCount = 15, CommentCount = 4
            });
    }
}

using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace _23DTHE1_pham_minh_vu.Models;

public class ApplicationDbContext : IdentityDbContext<User>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    public DbSet<Product> Products { get; set; }
    public DbSet<Post> Posts { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<PostLike> PostLikes { get; set; }
    public DbSet<Comment> Comments { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Bắt buộc gọi base để Identity cấu hình các bảng AspNetUsers, AspNetRoles...
        base.OnModelCreating(modelBuilder);

        // Toàn bộ bảng (kể cả Products, Posts) nằm trong schema "identity" thay vì "dbo"
        modelBuilder.HasDefaultSchema("identity");
        modelBuilder.Entity<User>(user =>
        {
            user.Property(u => u.Initials).HasMaxLength(5);
            user.Property(u => u.DisplayName).HasMaxLength(50);
            user.Property(u => u.AvatarUrl).HasMaxLength(500);
            user.Property(u => u.CoverUrl).HasMaxLength(500);
            user.Property(u => u.Bio).HasMaxLength(200);
        });

        // Xóa danh mục thì CategoryId của các sản phẩm thuộc danh mục đó về NULL (không xóa sản phẩm)
        modelBuilder.Entity<Product>()
            .HasOne(p => p.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(p => p.CategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        // Xóa tài khoản thì bài đăng ở lại nhưng không còn chủ (UserId = NULL)
        modelBuilder.Entity<Post>()
            .HasOne(p => p.User)
            .WithMany()
            .HasForeignKey(p => p.UserId)
            .OnDelete(DeleteBehavior.SetNull);

        // Thích: mỗi (bài, người) tối đa một dòng. Xóa bài thì xóa lượt thích theo (Cascade).
        // UserId dùng NoAction: SQL Server không cho phép nhiều đường cascade/set-null từ User tới cùng một bảng
        // (User -> Post[SetNull] -> PostLike[Cascade] đã là một đường), nên xóa hẳn một tài khoản cần xóa like/bình luận của nó trước.
        modelBuilder.Entity<PostLike>(like =>
        {
            like.HasKey(l => new { l.PostId, l.UserId });
            like.HasOne(l => l.Post).WithMany(p => p.Likes).HasForeignKey(l => l.PostId).OnDelete(DeleteBehavior.Cascade);
            like.HasOne(l => l.User).WithMany().HasForeignKey(l => l.UserId).OnDelete(DeleteBehavior.NoAction);
            like.HasIndex(l => new { l.UserId, l.CreatedAt });
        });

        // Bình luận: xóa bài thì xóa bình luận theo (Cascade)
        modelBuilder.Entity<Comment>(comment =>
        {
            comment.HasOne(c => c.Post).WithMany(p => p.Comments).HasForeignKey(c => c.PostId).OnDelete(DeleteBehavior.Cascade);
            comment.HasOne(c => c.User).WithMany().HasForeignKey(c => c.UserId).OnDelete(DeleteBehavior.NoAction);
            comment.HasIndex(c => new { c.PostId, c.CreatedAt });
        });

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

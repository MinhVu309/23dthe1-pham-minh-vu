using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace _23DTHE1_pham_minh_vu.Migrations
{
    /// <inheritdoc />
    public partial class AddPost : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Posts",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UserAvatar = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Content = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Image = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LikeCount = table.Column<int>(type: "int", nullable: false),
                    CommentCount = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Posts", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Posts",
                columns: new[] { "Id", "CommentCount", "Content", "CreatedAt", "Image", "LikeCount", "UserAvatar", "UserName" },
                values: new object[,]
                {
                    { 1, 3, "Hôm nay mình hoàn thành bài Tuần 6 môn Lập trình thiết bị di động!", new DateTime(2026, 10, 20, 8, 0, 0, 0, DateTimeKind.Utc), "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg", 12, "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg", "Phạm Minh Vũ" },
                    { 2, 1, "Flutter gọi API ASP.NET Core khá dễ, chỉ cần nhớ 10.0.2.2 khi chạy trên Android emulator.", new DateTime(2026, 10, 20, 9, 30, 0, 0, DateTimeKind.Utc), "https://flutter.github.io/assets-for-api-docs/assets/widgets/falcon.jpg", 8, "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg", "Nguyễn Văn A" },
                    { 3, 7, "Ai có tài liệu về Repository Pattern chia sẻ mình với nhé.", new DateTime(2026, 10, 21, 14, 15, 0, 0, DateTimeKind.Utc), null, 5, "https://flutter.github.io/assets-for-api-docs/assets/widgets/falcon.jpg", "Trần Thị B" },
                    { 4, 9, "Cuối tuần này cả nhóm cà phê và ôn thi nhé!", new DateTime(2026, 10, 22, 19, 0, 0, 0, DateTimeKind.Utc), "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg", 21, "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg", "Lê Văn C" },
                    { 5, 4, "Mới học xong phần CRUD với Entity Framework Core, cảm giác rất đã.", new DateTime(2026, 10, 23, 7, 45, 0, 0, DateTimeKind.Utc), "https://flutter.github.io/assets-for-api-docs/assets/widgets/falcon.jpg", 15, "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg", "Hoàng Thị D" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Posts");
        }
    }
}

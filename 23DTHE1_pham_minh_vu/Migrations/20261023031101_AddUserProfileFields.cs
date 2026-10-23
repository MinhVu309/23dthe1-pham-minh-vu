using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace _23DTHE1_pham_minh_vu.Migrations
{
    /// <inheritdoc />
    public partial class AddUserProfileFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AvatarUrl",
                schema: "identity",
                table: "AspNetUsers",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Bio",
                schema: "identity",
                table: "AspNetUsers",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CoverUrl",
                schema: "identity",
                table: "AspNetUsers",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DisplayName",
                schema: "identity",
                table: "AspNetUsers",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            // Tài khoản đã có: tên hiển thị mặc định = tên đăng nhập (cắt còn 50 ký tự)
            migrationBuilder.Sql(
                "UPDATE [identity].[AspNetUsers] SET [DisplayName] = LEFT([UserName], 50) WHERE [DisplayName] IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AvatarUrl",
                schema: "identity",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Bio",
                schema: "identity",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "CoverUrl",
                schema: "identity",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "DisplayName",
                schema: "identity",
                table: "AspNetUsers");
        }
    }
}

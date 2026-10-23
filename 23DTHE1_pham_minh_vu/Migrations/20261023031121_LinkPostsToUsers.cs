using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace _23DTHE1_pham_minh_vu.Migrations
{
    /// <inheritdoc />
    public partial class LinkPostsToUsers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "UserId",
                schema: "identity",
                table: "Posts",
                type: "nvarchar(450)",
                nullable: true);

            migrationBuilder.UpdateData(
                schema: "identity",
                table: "Posts",
                keyColumn: "Id",
                keyValue: 1,
                column: "UserId",
                value: null);

            migrationBuilder.UpdateData(
                schema: "identity",
                table: "Posts",
                keyColumn: "Id",
                keyValue: 2,
                column: "UserId",
                value: null);

            migrationBuilder.UpdateData(
                schema: "identity",
                table: "Posts",
                keyColumn: "Id",
                keyValue: 3,
                column: "UserId",
                value: null);

            migrationBuilder.UpdateData(
                schema: "identity",
                table: "Posts",
                keyColumn: "Id",
                keyValue: 4,
                column: "UserId",
                value: null);

            migrationBuilder.UpdateData(
                schema: "identity",
                table: "Posts",
                keyColumn: "Id",
                keyValue: 5,
                column: "UserId",
                value: null);

            migrationBuilder.CreateIndex(
                name: "IX_Posts_UserId",
                schema: "identity",
                table: "Posts",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Posts_AspNetUsers_UserId",
                schema: "identity",
                table: "Posts",
                column: "UserId",
                principalSchema: "identity",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Posts_AspNetUsers_UserId",
                schema: "identity",
                table: "Posts");

            migrationBuilder.DropIndex(
                name: "IX_Posts_UserId",
                schema: "identity",
                table: "Posts");

            migrationBuilder.DropColumn(
                name: "UserId",
                schema: "identity",
                table: "Posts");
        }
    }
}

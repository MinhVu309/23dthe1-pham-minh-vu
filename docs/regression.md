# Checklist hồi quy Tuần 6-7

Mục đích: sau mỗi thay đổi, chắc chắn các hành vi thầy sẽ chấm **không bị hỏng**.

## 1. Phần tự động (API) — chạy trước, mất vài giây

```bash
# Backend phải đang chạy:  cd 23DTHE1_pham_minh_vu && dotnet run --launch-profile http
docs/regression.sh                    # sau khi nâng cấp (GET bài đăng cần đăng nhập)
PHASE=baseline docs/regression.sh     # chỉ dùng cho mã baseline Tuần 6-7 (GET bài đăng không cần đăng nhập)
```

Script tự đăng ký `admin1` / `user1` nếu chưa có, và xóa lại mọi dữ liệu nó tạo. Nó kiểm tra:

| Nhóm | Nội dung |
|---|---|
| Đăng nhập | sai mật khẩu 401 (`status` là bool), token đúng role Admin/User, đăng ký trùng/yếu/role lạ → 400 |
| Sản phẩm | không token 401; User xem được, User thêm/sửa/xóa 403; Admin CRUD; tìm kiếm không phân biệt hoa thường; PUT id lệch 400 |
| Danh mục | User xem được, chỉ Admin thêm/sửa/xóa; xóa danh mục → sản phẩm về `categoryId = null` và vẫn còn |
| Bài đăng Tuần 6 | đủ trường JSON cũ (`userName`, `userAvatar`, `content`, `image`, `createdAt`, `likeCount`, `commentCount`); thêm/sửa/xóa bài của chính mình; sửa không đổi `createdAt` |

Kết quả mốc: baseline Tuần 6-7 = **40 đạt, 0 lỗi** (`PHASE=baseline`); sau nâng cấp mạng xã hội = **40 đạt, 0 lỗi** (`PHASE=upgrade`, mặc định).

Phần mạng xã hội có script riêng: `docs/social_tests.sh` (bài đăng gắn tài khoản, sửa/xóa theo quyền, thích, bình luận, thông báo,
phân trang, hồ sơ, upload ảnh kể cả tệp giả mạo, token cũ). Kết quả: **140 đạt, 0 lỗi**. Script tự dọn dữ liệu, ảnh đã upload và
khôi phục hồ sơ `user1`. Cần Docker `sqlserver` đang chạy nếu muốn kiểm tra thêm việc xóa bài kéo theo xóa like/bình luận trong CSDL.

> Khác biệt có chủ đích so với Tuần 6: `GET api/PostApi` giờ **cần đăng nhập**, sửa/xóa bài chỉ chủ bài hoặc Admin (bài mẫu cũ chỉ Admin),
> `likeCount`/`commentCount` không còn sửa được qua PUT. Ba mục này khác với phần "Bài đăng Tuần 6" ở trên nên script dùng `PHASE`.

## 2. Phần chạy tay trên Android emulator (Pixel 7)

Chạy: `docker start sqlserver` → `dotnet run --launch-profile http` → `flutter run -d emulator-5554` (trong `pham_minh_vu_23dthe1`).

- [ ] Mở app lần đầu → màn hình **Đăng nhập** (không vào thẳng app).
- [ ] Đăng ký tài khoản (mật khẩu yếu → hiện lỗi của server; đủ mạnh → quay về đăng nhập, điền sẵn tên).
- [ ] Đăng nhập **User** → trang chính (Chợ + Bảng tin); **không có** nút thêm sản phẩm; chi tiết sản phẩm **không có** sửa/xóa.
- [ ] Đăng nhập **Admin** → `AdminScreen` (tab Sản phẩm / Danh mục); có nút thêm/sửa/xóa.
- [ ] Thoát hẳn app rồi mở lại → vào **đúng** màn hình theo role (Admin vào Admin, User vào trang User), không phải đăng nhập lại.
- [ ] Đăng xuất (có hộp thoại xác nhận) → về Đăng nhập; mở lại app vẫn ở Đăng nhập.
- [ ] Token hết hạn → về Đăng nhập kèm thông báo "Phiên đăng nhập đã hết hạn" (thử nhanh: `JWTKey__TokenExpiryTimeInHour=0.004 dotnet run --launch-profile http`).
- [ ] Sản phẩm: danh sách, tìm kiếm (gõ rồi chờ ~0,4 s), chi tiết, thêm, sửa, xóa có xác nhận; SnackBar thành công/thất bại; ảnh "Cập nhật sau" hiện icon thay thế.
- [ ] Danh mục (Admin): thêm/sửa/xóa; sản phẩm có danh mục hiện tên danh mục + chip lọc; xóa danh mục → sản phẩm sang "Chưa phân loại".
- [ ] Bảng tin: danh sách bài, kéo để làm mới, đăng bài, sửa bài, xóa bài có xác nhận. *(sau nâng cấp: User chỉ sửa/xóa được bài của mình; bài mẫu cũ báo "Bạn không có quyền thực hiện thao tác này")*
- [ ] Đăng ký → nút SIM ở ô số điện thoại mở hộp thoại Google và điền số (smart_auth, chỉ Android).

## 3. Sao lưu / khôi phục CSDL

Bản sao lưu trước khi nâng cấp: `backups/23DTHE1_pham_minh_vu_truoc_nang_cap_20261023_100856.bak`
(bản gốc nằm trong container: `/var/opt/mssql/backup/…`). Thư mục `backups/` nằm trong `.gitignore`.

Khôi phục (mật khẩu `sa` lấy từ `appsettings.json`, **không** ghi vào tài liệu):

```bash
docker cp backups/<tên-file>.bak sqlserver:/var/opt/mssql/backup/
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" \
  -Q "ALTER DATABASE [23DTHE1_pham_minh_vu] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
      RESTORE DATABASE [23DTHE1_pham_minh_vu] FROM DISK = N'/var/opt/mssql/backup/<tên-file>.bak' WITH REPLACE;
      ALTER DATABASE [23DTHE1_pham_minh_vu] SET MULTI_USER;"
```

## 4. Quay về bản đã nộp

```bash
git checkout main          # baseline "baseline Tuan6-7"
```

`appsettings.json` và `.env` không nằm trong git (có bí mật) nên luôn còn nguyên trên đĩa;
mẫu ở `23DTHE1_pham_minh_vu/appsettings.example.json` và `pham_minh_vu_23dthe1/.env.example`.
Nếu quay về `main` sau khi đã `dotnet ef database update` của nhánh nâng cấp, hãy khôi phục CSDL từ file `.bak` ở mục 3
(CSDL mới có bảng/cột mà code cũ không biết; code cũ vẫn chạy được nhưng cần kiểm tra).

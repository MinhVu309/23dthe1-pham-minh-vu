# 23DTHE1_pham_minh_vu – SmartCheck API (ASP.NET Core 8)

Xem kế hoạch đầy đủ trong [PLAN.md](PLAN.md).

## Chạy thử trên máy
```bash
dotnet restore
dotnet run            # mở /swagger
```
1. Sửa `ConnectionStrings:DefaultConnection` trong `appsettings.json` (SQL Server; mặc định LocalDB).
2. Lần chạy đầu tự tạo bảng (`EnsureCreated`) và seed: role Admin/Manager/Employee, tài khoản
   `admin@smartcheck.local` / `Admin@123456`, 1 ca làm, 1 địa điểm mẫu, 1 phòng ban.
3. Chưa cấu hình `Smtp:*` thì mã OTP được **in ra console** (log cảnh báo) để test.

## Cấu hình khi chạy lần đầu
`appsettings.json` (chứa mật khẩu, khoá ký JWT/QR) **không nằm trong git**. Sao chép mẫu rồi điền giá trị của bạn:
```bash
cp appsettings.example.json appsettings.json
docker compose up -d && dotnet run   # DB Docker + tự tạo DB, seed admin admin@smartcheck.local / Admin@123456
```
`appsettings.Production.json` (cũng không commit) ghi đè khi chạy trên host.

## Cấu hình khi deploy (đổi trong appsettings.Production.json hoặc biến môi trường)
- `ConnectionStrings:DefaultConnection` – DB trên host
- `Jwt:Key`, `Qr:Secret` – chuỗi bí mật ≥ 32 ký tự
- `Smtp:Host/Port/User/Password/From` – Gmail: bật 2FA + tạo App Password, Host `smtp.gmail.com`, Port 587
- `Google:ClientId` – OAuth Web client ID (dùng làm `serverClientId` bên Flutter)
- `Seed:AdminEmail/AdminPassword`

Biến môi trường dùng dấu `__`, ví dụ `ConnectionStrings__DefaultConnection`.

## Đăng ký và xác minh email
`POST /api/auth/register` tạo tài khoản **chưa xác minh** (role Employee) và gửi mã 6 số tới email (thư "Mã xác minh email SmartCheck").
Người dùng nhập mã ở `POST /api/auth/verify-otp` thì email được đánh dấu đã xác minh và nhận JWT (không cần đăng nhập lại).

- Email chưa xác minh mà đăng ký lại (ví dụ lần đầu gõ nhầm, hoặc bị người khác đăng ký giùm) thì **ghi đè tên và mật khẩu** rồi gửi mã mới, để chủ hộp thư thật không bị chiếm email. Ai cũng vẫn phải nhập mã gửi về hộp thư mới vào được.
- Email đã xác minh mà đăng ký lại → 400 "Email … is already taken".
- Đăng nhập bằng Google, Admin tạo nhân viên và tài khoản mẫu được coi là đã xác minh. Tài khoản đăng ký từ trước chưa xác minh sẽ được xác minh ở lần nhập OTP đăng nhập kế tiếp.
- App mới chạy được với server cũ (không có cờ `requiresEmailVerification`) và app cũ chạy được với server mới (đăng ký xong quay về đăng nhập, nhận mã xác minh ở lần đăng nhập đầu).

## Dữ liệu mẫu để demo (tắt mặc định)
Đặt `Seed:Demo` = `true` (trong `appsettings.json`, `appsettings.Production.json` hoặc biến môi trường `Seed__Demo=true`)
rồi khởi động lại. Lần chạy đầu tạo dữ liệu, các lần sau tự bỏ qua:

| Loại | Nội dung |
|---|---|
| Tài khoản | 1 **Manager** (`manager`) và 5 **Employee** (`nv01` … `nv05`), mã nhân viên `DEMO-…` |
| Danh mục | 4 phòng ban, 3 ca (hành chính, sáng, chiều), địa điểm "Chi nhánh Quận 1" thêm vào "Văn phòng chính" |
| Chấm công | ~3 tuần lịch sử các ngày đã qua (có đi trễ, về sớm, toạ độ quanh địa điểm); **không** có lượt của hôm nay để chấm công thật |
| Khác | 4 đơn nghỉ (chờ duyệt, đã duyệt, từ chối), 3 cảnh báo gian lận ghi "(dữ liệu mẫu)" |

- **Email:** nếu `Seed:AdminEmail` là Gmail thì tài khoản có dạng `tên+manager@gmail.com`, `tên+nv01@gmail.com`…; thư OTP về
  chính hộp thư của admin. Email khác Gmail thì dạng `manager@{domain}`. Đặt `Seed:DemoEmailBase` để chọn địa chỉ gốc khác.
- **Mật khẩu chung:** `Demo@123456`, đổi bằng `Seed:DemoPassword`. Chỉ dùng cho demo, **đừng bật trên hệ thống thật**.
- **Xoá dữ liệu mẫu:** Admin → Nhân viên → xoá từng tài khoản `DEMO-…` (lịch sử, đơn nghỉ, cảnh báo của họ xoá theo).
  Phòng ban, ca, địa điểm thêm vào thì xoá riêng nếu không cần.
- Chạy mã ở `Data/DemoSeeder.cs`.

## Luồng test nhanh trên Swagger
1. `POST /api/auth/login` (admin) → xem OTP trong log/email → `POST /api/auth/verify-otp` → copy `token` → **Authorize**.
2. `GET /api/qr/current?locationId=1` → lấy `token` QR.
3. Đăng ký nhân viên → login + OTP → `POST /api/attendance/check-in` với toạ độ trong bán kính.

## Dùng migration thay EnsureCreated (khuyến nghị khi nộp)
```bash
dotnet tool install --global dotnet-ef
dotnet ef migrations add Init
# Program.cs: đổi EnsureCreatedAsync() -> MigrateAsync()
```

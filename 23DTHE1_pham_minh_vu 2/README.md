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

## Cấu hình khi deploy (đổi trong appsettings.Production.json hoặc biến môi trường)
- `ConnectionStrings:DefaultConnection` – DB trên host
- `Jwt:Key`, `Qr:Secret` – chuỗi bí mật ≥ 32 ký tự
- `Smtp:Host/Port/User/Password/From` – Gmail: bật 2FA + tạo App Password, Host `smtp.gmail.com`, Port 587
- `Google:ClientId` – OAuth Web client ID (dùng làm `serverClientId` bên Flutter)
- `Seed:AdminEmail/AdminPassword`

Biến môi trường dùng dấu `__`, ví dụ `ConnectionStrings__DefaultConnection`.

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

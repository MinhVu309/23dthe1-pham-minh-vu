# PLAN.md — App chấm công nhân viên SmartCheck (Flutter + ASP.NET Core API)

> Cho Claude Code. Bài kiểm tra giữa kì LTDD (40%), **Đề 2**. Hạn **23h59 ngày 29/10/2026**.
> Backend (`23DTHE1_pham_minh_vu`) đã có khung, cần build + deploy. Việc chính còn lại là app Flutter `23dthe1_pham_minh_vu`.
> Chọn làm: **(e) quét QR** · **(b) chia sẻ vị trí** · **(a) khuôn mặt** · tính năng mới: **chống fake GPS**.

## 0. Hợp đồng API (đã viết trong backend, KHÔNG đoán khác)
- `baseUrl` đặt ở 1 chỗ duy nhất (`lib/core/config.dart`), là URL **đã deploy** (https). Cấm `localhost`, `10.0.2.2`.
- Auth: header `Authorization: Bearer <jwt>`. Lưu JWT bằng `flutter_secure_storage`. Lỗi trả JSON `{message}` hoặc `{code,message,...}`.
- Enum trả về dạng **chuỗi**: `CheckIn|CheckOut`, `Pending|Approved|Rejected`. `Timestamp` là **UTC** (ISO 8601) → đổi sang giờ máy khi hiển thị.
- **Đăng nhập 2 bước:**
  - `POST /api/auth/login {userNameOrEmail,password}` → `{requiresOtp:true}` (server gửi Email OTP 6 số, hạn 5 phút, tối đa 5 lần thử).
  - `POST /api/auth/verify-otp {userNameOrEmail,code,deviceId?}` → `{token,role,userId,fullName,email}`. `role` ∈ `Admin|Manager|Employee` → điều hướng.
  - `POST /api/auth/resend-otp {userNameOrEmail}` · `POST /api/auth/register {email,password,fullName}` (mặc định Employee) · `POST /api/auth/google-login {idToken}` (trả luôn `AuthResult`, không OTP) · `GET /api/auth/me`.
- **CRUD:**
  - `/api/departments`, `/api/shifts`, `/api/locations`: đọc = đã đăng nhập, ghi = Admin. `GET` trả `{total,page,pageSize,items}`.
  - `/api/employees` (Admin/Manager; ghi = Admin): `GET ?q&departmentId&page&pageSize`, `POST {email,password,fullName,employeeCode?,departmentId?,role}`, `PUT {fullName,employeeCode?,departmentId?,role?,isActive}`, `DELETE`, `PUT {id}/face {embedding:[float]}`, `POST {id}/reset-device`.
  - `/api/leaves`: `GET ?status` (nhân viên thấy đơn mình, Admin/Manager thấy tất cả, trả **mảng**), `POST {fromDate,toDate,reason}`, `PUT {id}` / `DELETE {id}` (chỉ khi `Pending`), `POST {id}/review {approve}`. Ngày dạng `yyyy-MM-dd`.
- **QR động:** `GET /api/qr/current?locationId=` (Admin/Manager) → `{token,ttlSeconds,location}`. Token dạng `SC1.{locationId}.{expUnix}.{hmac}` (hạn ~45 s). Màn hình điểm chấm công gọi lại **mỗi 30 s** và vẽ lại QR. App nhân viên **chỉ đọc chuỗi QR rồi gửi nguyên lên server**, không tự kiểm tra.
- **Chấm công:** `POST /api/attendance/check-in` và `/check-out`, body:
  `{qrToken,latitude,longitude,accuracy,isMocked,deviceId,faceVerified,faceEmbedding?}`.
  - 200: `{id,type,timeLocal,isLate,isEarlyLeave,distance,flags[]}`.
  - Lỗi (`code`): `QR_INVALID` · `LOCATION_NOT_FOUND` · `OUT_OF_RANGE` · `FRAUD_SUSPECTED` (+`reasons[]`, HTTP 403) · `FACE_REQUIRED` · `FACE_MISMATCH` (403) · `ALREADY_DONE` (409) · `NO_CHECKIN` (409). Mỗi code có thông báo thân thiện riêng.
  - `GET /api/attendance/my?days=` (mảng) · `GET /api/attendance?userId&from&to&page` (Admin/Manager, `{total,items}` có lat/lng để vẽ bản đồ) · `GET /api/attendance/report?year&month&userId` → `{year,month,rows[{userId,name,daysWorked,lateCount,earlyLeaveCount}]}`.
- **Cảnh báo gian lận:** `GET /api/fraud-alerts?resolved` · `POST {id}/resolve` (Admin/Manager).
- **Tài khoản seed:** `admin@smartcheck.local` / `Admin@123456` (đổi khi deploy). Địa điểm mẫu id=1 (toạ độ TP.HCM, **phải sửa theo nơi demo**).
- **Chống fake GPS (server chặn):** `isMocked=true` · `accuracy` ≤ 0 hoặc > 100 m · `deviceId` khác máy đã gắn · tốc độ > 60 m/s so với lần trước. Gắn cờ: trùng toạ độ y hệt người khác trong 2 phút. Mọi vi phạm ghi `FraudAlerts`.
- **Khuôn mặt:** nhân viên đã đăng ký vector → server so cosine ≥ 0.6, **bắt buộc gửi `faceEmbedding`**. Chưa đăng ký → chỉ cần `faceVerified=true` (đã qua liveness).

## 1. Ràng buộc (đề của thầy)
- Chỉ **Flutter** (Dart). Backend ASP.NET Core. Android trước.
- **Tên project cá nhân:** thư mục/repo `23dthe1_pham_minh_vu`, package Dart `pham_minh_vu_23dthe1` (Dart không cho tên bắt đầu bằng số), `applicationId` `com.phamminhvu.chamcong`. Sai tên = 0 điểm.
- **UI không được giống bài các bạn cùng nhóm** (rớt môn): giữ bảng màu, bố cục, cấu trúc thư mục riêng.
- API phải deploy, không localhost. Cả nhóm chạy được (APK + tài khoản mẫu + README).
- Quét QR bằng **ML Kit** (`google_mlkit_barcode_scanning`) + `camera`; khuôn mặt bằng `google_mlkit_face_detection`. Android `minSdk 23`, khoá màn hình dọc ở các màn camera.
- Hỏi trước khi thêm dependency ngoài danh sách ở mục 2.

## 2. Cấu trúc
```
lib/ main.dart | core/(config, theme, router, api_client, secure_store)
     data/(models, repositories: auth, employee, department, shift, location, leave, attendance, fraud)
     services/(device_id, location_service, face_service)
     features/ auth | admin | employee | manager_qr | scan | map | reports
assets/ ml/mobilefacenet.tflite (nếu có kịp)
```
Packages: `dio`, `provider` (hoặc `flutter_riverpod`), `flutter_secure_storage`, `google_sign_in`, `camera`, `google_mlkit_barcode_scanning`, `google_mlkit_face_detection`, `tflite_flutter`, `geolocator`, `permission_handler`, `flutter_map`, `latlong2`, `qr_flutter`, `device_info_plus`, `intl`.

## 3. Giai đoạn
**0. Backend: DB Docker → build → lên mạng (người dùng làm cùng Claude Code).**
- *DB dev bằng Docker:* `docker compose up -d` (file `docker-compose.yml` ở gốc backend: SQL Server 2022, cổng 1433, user `sa`, mật khẩu `SmartCheck@123`, volume `smartcheck-sql-data`). Chờ `docker compose ps` báo `healthy`. Chuỗi kết nối dev nằm sẵn trong `appsettings.Development.json`: `Server=localhost,1433;Database=SmartCheckDb;User Id=sa;Password=SmartCheck@123;TrustServerCertificate=True;Encrypt=False`. Mac chip Apple Silicon: bật "Use Rosetta" trong Docker Desktop (image chỉ có amd64). Docker chỉ dùng trên máy dev.
- `dotnet restore && dotnet build`, sửa lỗi biên dịch nếu có (khung viết chưa build được). `dotnet run` → lần đầu tự tạo DB `SmartCheckDb` + seed (role, admin, ca, địa điểm, phòng ban).
- Điền cấu hình **bản deploy**: `ConnectionStrings__DefaultConnection` trỏ tới SQL Server **trên mạng** (hosting/VPS, không dùng DB Docker trên máy), `Jwt:Key`, `Qr:Secret` (≥32 ký tự), SMTP (Gmail App Password), `Google:ClientId`. Sửa toạ độ địa điểm mẫu. Deploy giống Tuần 6.
- *Xong khi:* chạy local với DB Docker được; và mở `https://<domain>/swagger`, login admin → OTP → token chạy được trên URL thật.

**A. Khung app & đăng nhập.** Tạo project Flutter theo mục 1-2, theme riêng, `ApiClient` (dio + interceptor gắn JWT, bắt 401 → về login). Màn: Đăng nhập → Nhập OTP (đếm ngược, gửi lại) → Đăng ký → Google. Điều hướng theo `role`: Admin → trang quản trị, Manager → dashboard quản lý, Employee → dashboard nhân viên. *Xong khi:* 3 role vào đúng 3 trang trên máy thật gọi API deploy; tắt mở lại app vẫn giữ đăng nhập.

**B. CRUD quản trị (4,5đ).** Employees (tìm kiếm, lọc phòng ban, phân trang, tạo/sửa/xoá/khoá), Departments, Shifts + Locations (chọn toạ độ trên bản đồ, bán kính), Leaves (nhân viên tạo/sửa/huỷ, Admin/Manager duyệt). Form có validate, hỏi xác nhận khi xoá, xử lý lỗi `409`. *Xong khi:* 4 bảng đủ Create/Read/Update/Delete chạy trên API deploy.

**C. QR chấm công (e) — làm trước.** (1) Màn "Điểm chấm công" cho Admin/Manager: chọn địa điểm, hiện QR toàn màn hình bằng `qr_flutter`, tự gọi `/api/qr/current` mỗi 30 s, có đếm ngược. (2) Màn quét cho nhân viên: `camera` + `BarcodeScanner(formats:[qrCode])` xử lý từng frame (cờ `_busy`), đọc được thì dừng stream và trả chuỗi về luồng chấm công. Có nút bật đèn, hướng dẫn, xử lý từ chối quyền. *Xong khi:* quét QR trên màn máy khác, chấm công vào/ra thành công (tạm `faceVerified=true`, vị trí lấy tay) và QR cũ sau ~1 phút bị `QR_INVALID`.

**D. Vị trí (b) + chống fake GPS (mới).** `geolocator` lấy toạ độ độ chính xác cao, xin quyền (xử lý từ chối vĩnh viễn → mở cài đặt), gửi `latitude/longitude/accuracy/isMocked/deviceId`. `deviceId` từ `device_info_plus`. Màn kết quả hiện khoảng cách và lý do bị từ chối theo `code`/`reasons`. Admin: bản đồ `flutter_map` (OpenStreetMap) vẽ vòng tròn địa điểm + điểm chấm công của nhân viên; màn **Cảnh báo gian lận** (danh sách, đánh dấu đã xử lý). *Xong khi:* bật mock location thì bị chặn và có cảnh báo trên màn Admin; đứng ngoài bán kính thì báo `OUT_OF_RANGE`.

**E. Khuôn mặt (a).** Tầng 1 (bắt buộc): `camera` trước + `google_mlkit_face_detection` (enableClassification) — đúng 1 mặt, yêu cầu chớp mắt hoặc quay đầu ngẫu nhiên → `faceVerified=true`. Tầng 2 (nếu kịp): `tflite_flutter` + MobileFaceNet tính vector, màn "Đăng ký khuôn mặt" gọi `PUT /employees/{id}/face`, lúc chấm công gửi `faceEmbedding`. Chưa chắc giá trị mean/std chuẩn hoá của model thì **hỏi**, không đoán. *Xong khi:* không chớp mắt/không có mặt thì không chấm công được; tầng 2 (nếu làm) người lạ bị `FACE_MISMATCH`.

**F. Lịch sử, báo cáo, hoàn thiện nghiệp vụ.** Nhân viên: lịch sử `/attendance/my`, bảng công tháng, trạng thái đi trễ/về sớm. Admin/Manager: danh sách chấm công theo ngày/nhân viên, bảng công tháng (`/attendance/report`), nút reset thiết bị của nhân viên.

**G. Giao diện, kiểm thử, đóng gói.** Theme riêng nhất quán, trạng thái loading/lỗi/trống, bắt lỗi mạng. Test ≥ 2 máy Android thật 3 role. `flutter build apk --release`, README (cách chạy, `baseUrl`, tài khoản mẫu admin + 1 nhân viên), ảnh chụp màn hình. Chuẩn bị kịch bản demo 3 chức năng + chống fake GPS.

## 4. Ưu tiên nếu thiếu thời gian (hạn 23h59)
Bắt buộc: **0 → A → B → C** (có app chạy trên API deploy + CRUD + QR). Rồi **D** (vị trí + chống fake GPS, ăn 1đ tính năng mới), **E tầng 1**, **F**, **G**. E tầng 2 (so khớp vector) và bản đồ Admin là phần cộng thêm. Dừng thêm tính năng lúc **22h**, dành 22h–23h30 cho build APK, test, README, nộp.

## 5. Quy tắc cho Claude Code
- Mỗi phase một nhánh git, commit nhỏ, chạy `flutter analyze` + `flutter test` trước khi báo xong. Backend: `dotnet build` sạch cảnh báo lỗi.
- Không đoán API: đối chiếu mục 0 hoặc mở `/swagger`; mơ hồ thì hỏi.
- Không hardcode `baseUrl`, secret, tài khoản trong nhiều chỗ; mọi cấu hình ở `core/config.dart`.
- Client **không tự quyết** QR/vị trí/gian lận hợp lệ — server là nơi quyết định; app chỉ thu thập và hiển thị.
- Không in JWT/OTP/ảnh mặt ra log.
- Cuối mỗi phase tóm tắt: đã làm gì, chạy thế nào, còn tồn đọng.

## 6. Prompt khởi động
> Đọc PLAN.md. Bắt đầu Phase 0: trong thư mục backend `23DTHE1_pham_minh_vu` chạy `docker compose up -d` và đợi SQL Server `healthy`, rồi `dotnet restore` và `dotnet build`, sửa mọi lỗi biên dịch (khung này chưa từng được build). Chạy `dotnet run` với DB Docker, thử login admin trên Swagger, rồi cho mình biết cần điền gì vào cấu hình để deploy (DB trên mạng, SMTP, secret). Chưa động vào Flutter. Tóm tắt rồi chờ mình duyệt trước khi sang Phase A.

## 7. Checklist nộp bài
- [ ] Tên project cá nhân (`23dthe1_pham_minh_vu`), UI khác các bạn trong nhóm
- [ ] `baseUrl` là URL deploy; Swagger mở được; đã đổi `Jwt:Key`, `Qr:Secret`, mật khẩu admin
- [ ] Bản deploy dùng SQL Server trên mạng (không phải DB Docker trên máy); đã bỏ `appsettings.Development.json` khỏi bản deploy hoặc không dùng mật khẩu `sa` mẫu
- [ ] Đủ: đăng ký/đăng nhập + OTP + OAuth, 3 role vào đúng trang, 4 bảng CRUD
- [ ] Demo được: QR, vị trí, khuôn mặt, chống fake GPS
- [ ] APK release + README + tài khoản mẫu
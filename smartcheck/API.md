# SmartCheck API – hướng dẫn dùng chung cho các thành viên

Backend đã deploy sẵn, **dùng chung** cho cả nhóm; mỗi người tự làm giao diện riêng và chỉ cần gọi API này. Không cần chạy hay sửa backend.

| | |
|---|---|
| **Base URL** | `https://vupham309-001-site1.etempurl.com` |
| **Swagger** (xem và thử API trực tiếp) | [`/swagger`](https://vupham309-001-site1.etempurl.com/swagger) · đặc tả JSON: `/swagger/v1/swagger.json` |
| **CORS** | Mở cho mọi nguồn, nên giao diện web cũng gọi được |

Host miễn phí "ngủ" khi nhàn rỗi: **request đầu tiên có thể chậm 10–30 giây**, đặt timeout đủ lớn.

## Quy ước chung
- Body và kết quả đều là JSON. Gọi API cần đăng nhập thì gắn header `Authorization: Bearer <token>` (token hết hạn sau 12 giờ; hết hạn thì server trả **401**).
- **Enum trả về dạng chuỗi**: `CheckIn` / `CheckOut`, `Pending` / `Approved` / `Rejected`, role `Admin` / `Manager` / `Employee`.
- **Thời gian trong dữ liệu là UTC** (`2026-10-29T01:05:00Z`), hãy đổi sang giờ máy khi hiển thị. Riêng kết quả chấm công có `timeLocal` kèm múi giờ `+07:00`. Ngày của đơn nghỉ phép dạng `yyyy-MM-dd`. Giờ của ca làm việc dạng `HH:mm:ss`.
- Danh sách phân trang trả `{ total, page, pageSize, items }` (riêng `/api/leaves`, `/api/attendance/my`, `/api/fraud-alerts` trả thẳng mảng).
- **Lỗi** có một trong các dạng: `{ "message": "..." }`, `{ "code": "...", "message": "...", "reasons": [...] }` (chấm công) hoặc `{ "errors": ["..."] }` (đăng ký, mật khẩu).

## Đăng nhập
Kết quả đăng nhập thành công là `{ token, role, userId, fullName, email }`.

| Việc | Cách gọi |
|---|---|
| **Đăng ký** | `POST /api/auth/register {email, password, fullName}` → server gửi mã 6 số tới email (`requiresEmailVerification: true`) → `POST /api/auth/verify-otp {userNameOrEmail: <email>, code}` → nhận token |
| **Đăng nhập** (2 bước) | `POST /api/auth/login {userNameOrEmail, password}` → `{ requiresOtp: true }` (mã 6 số gửi về email) → `POST /api/auth/verify-otp {userNameOrEmail, code}` → token |
| Gửi lại mã | `POST /api/auth/resend-otp {userNameOrEmail}` |
| **Quên mật khẩu** | `POST /api/auth/forgot-password {email}` → mã về email → `POST /api/auth/reset-password {email, code, newPassword}` → đổi xong nhận token luôn |
| Google | `POST /api/auth/google-login {idToken}` (idToken lấy bằng client ID **Web** của dự án; xem lưu ý bên dưới) |
| **Bật vân tay/khuôn mặt** | (đã đăng nhập) `POST /api/auth/biometric/enroll {deviceId}` → `{ token, expiresAt }` (token gắn với thiết bị, sống 30 ngày; gọi lại thì token cũ của thiết bị đó bị thu hồi) |
| **Đăng nhập bằng vân tay/khuôn mặt** | `POST /api/auth/biometric/login {deviceId, token}` → như `verify-otp` (nhận JWT). Sai/hết hạn/bị thu hồi/khác thiết bị → 401 `BIOMETRIC_INVALID`, quay về mật khẩu + OTP. App chỉ gọi sau khi vân tay/khuôn mặt của máy đã khớp |
| Tắt vân tay/khuôn mặt | (đã đăng nhập) `POST /api/auth/biometric/revoke {deviceId}` → 204. Đổi mật khẩu bằng "quên mật khẩu" cũng thu hồi mọi token sinh trắc của tài khoản |
| Hồ sơ của mình | `GET /api/auth/me` → `{ id, fullName, email, employeeCode, departmentId, role, hasFace, deviceBound }` |

Mã OTP sống **5 phút**, thử tối đa **5 lần**; yêu cầu gửi mã quên mật khẩu lại trong vòng 1 phút bị bỏ qua. Mật khẩu: tối thiểu 6 ký tự, có chữ thường và chữ số (luật của server; không bắt buộc chữ hoa hay ký tự đặc biệt).

### Tài khoản để thử
- **Hãy tự đăng ký bằng email thật của mình** (mã xác minh về hộp thư của bạn), mặc định role **Employee**.
- Các tài khoản mẫu `…+manager@…`, `…+nv01@…` có mã OTP gửi về hộp thư của chủ dự án nên **người khác không dùng được**.
- Muốn thử chức năng **Manager/Admin** (xem QR, bảng công, CRUD…) thì nhờ chủ dự án nâng role cho tài khoản của bạn (hoặc xin tài khoản Admin).
- Đăng nhập Google chỉ chạy với email nằm trong danh sách người dùng thử của dự án Google (ứng dụng đang ở chế độ Testing). Các bạn dùng đăng ký bằng email cho dễ.

## Quyền theo từng nhóm API
| Nhóm | Ai gọi được |
|---|---|
| `/api/departments`, `/api/shifts`, `/api/locations` | Đọc: mọi người đã đăng nhập. Thêm/sửa/xoá: **Admin** |
| `/api/employees` (kèm `PUT {id}/face`, `POST {id}/reset-device`) | Xem: Admin/Manager. Ghi: **Admin** |
| `/api/leaves` | Nhân viên chỉ thấy và tạo/sửa/huỷ đơn **của mình** (khi còn `Pending`); Admin/Manager thấy tất cả và duyệt bằng `POST {id}/review {approve}` |
| `GET /api/qr/current?locationId=` | Admin/Manager |
| `POST /api/attendance/check-in`, `check-out`, `GET /my` | Mọi người đã đăng nhập |
| `GET /api/attendance`, `GET /api/attendance/report` | Admin/Manager (riêng `report`, nhân viên chỉ xem của mình) |
| `/api/fraud-alerts` | Admin/Manager (xoá: Admin) |

Ví dụ dữ liệu gửi lên:
```jsonc
// POST /api/shifts
{ "name": "Ca hành chính", "startTime": "08:00:00", "endTime": "17:00:00", "lateToleranceMinutes": 10 }
// POST /api/locations
{ "name": "Văn phòng", "address": "…", "latitude": 10.8019, "longitude": 106.7144, "radiusMeters": 150, "shiftId": 1 }
// POST /api/leaves
{ "fromDate": "2026-11-02", "toDate": "2026-11-03", "reason": "Việc gia đình" }
// PUT /api/employees/{id}
{ "fullName": "…", "employeeCode": "NV01", "departmentId": 1, "role": "Employee", "isActive": true }
```

## Luồng chấm công (phần quan trọng nhất)
1. **Điểm chấm công** (Admin/Manager) gọi `GET /api/qr/current?locationId=…` → `{ token, ttlSeconds, location }`. Token dạng `SC1.{locationId}.{hạn}.{chữ ký}`, sống khoảng **45 giây**, nên gọi lại mỗi **30 giây** và vẽ lại mã QR.
2. **Nhân viên** quét mã và gửi **nguyên chuỗi** đó lên, không tự kiểm tra:
```jsonc
// POST /api/attendance/check-in   (hoặc /check-out)
{
  "qrToken": "SC1.1.1730000000.xxxx",
  "latitude": 10.8019, "longitude": 106.7144,
  "accuracy": 8,            // mét, phải > 0 và ≤ 100
  "isMocked": false,        // cờ vị trí giả lập do hệ điều hành báo (Position.isMocked)
  "deviceId": "một-mã-cố-định-của-máy",
  "faceVerified": true,     // đã qua bước chớp mắt / quay đầu
  "faceEmbedding": null     // chỉ cần khi tài khoản đã đăng ký vector khuôn mặt
}
```
3. Thành công (200): `{ id, type, timeLocal, isLate, isEarlyLeave, distance, flags[] }`.

Server kiểm tra theo thứ tự và dừng ở lỗi đầu tiên (đây là **mã lỗi** trong `code`):

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| `QR_INVALID` | 400 | QR sai chữ ký hoặc đã hết hạn |
| `LOCATION_NOT_FOUND` | 400 | Địa điểm trong QR không còn |
| `OUT_OF_RANGE` | 400 | Ngoài bán kính cho phép (`message` ghi khoảng cách) |
| `FRAUD_SUSPECTED` | 403 | Nghi gian lận, kèm `reasons[]` |
| `FACE_REQUIRED` / `FACE_MISMATCH` | 400 / 403 | Thiếu hoặc không khớp khuôn mặt |
| `ALREADY_DONE` | 409 | Hôm nay đã chấm công vào (hoặc ra) rồi |
| `NO_CHECKIN` | 409 | Chấm công ra khi chưa chấm công vào |

**Chống gian lận** (do server quyết định): `isMocked=true`, `accuracy` ≤ 0 hoặc > 100 m, **`deviceId` khác máy đã gắn** (tài khoản gắn với máy ở lần chấm công đầu tiên; Admin có `POST /api/employees/{id}/reset-device`), di chuyển nhanh hơn 60 m/s so với lần trước. Trùng toạ độ y hệt người khác trong 2 phút chỉ bị gắn cờ. Mỗi vi phạm đều ghi vào `/api/fraud-alerts`.
→ Vì vậy `deviceId` phải **ổn định** trên mỗi máy (đừng sinh mã mới mỗi lần mở app).

Các API xem lại: `GET /api/attendance/my?days=30` (lịch sử của mình), `GET /api/attendance?userId&from&to&page&pageSize` (toàn bộ, có toạ độ để vẽ bản đồ), `GET /api/attendance/report?year&month&userId` (bảng công tháng).

## Thử nhanh bằng curl
```bash
BASE=https://vupham309-001-site1.etempurl.com
curl -s -X POST $BASE/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userNameOrEmail":"email@cua.ban","password":"matkhau1"}'          # → mã OTP về email
curl -s -X POST $BASE/api/auth/verify-otp -H 'Content-Type: application/json' \
  -d '{"userNameOrEmail":"email@cua.ban","code":"123456"}'               # → token
curl -s $BASE/api/auth/me -H "Authorization: Bearer <token>"
```

## Lưu ý khi dùng chung một backend
- **Cả nhóm dùng chung một cơ sở dữ liệu.** Đừng xoá hay sửa phòng ban, ca, địa điểm, nhân viên mà bạn không tạo. Muốn thử thoải mái, hãy **tạo địa điểm và ca riêng cho mình** (cần quyền Admin).
- Mỗi tài khoản chỉ chấm công **một lần vào và một lần ra mỗi ngày**.
- Dữ liệu mẫu (nhân viên có mã `DEMO-…`, cảnh báo ghi "(dữ liệu mẫu)") là của chủ dự án, cứ để nguyên.
- Đừng gọi đăng ký hoặc gửi OTP hàng loạt: mỗi lần là một email thật, dễ bị Gmail chặn gửi.
- Cần thêm một API hoặc thấy lỗi từ server: báo cho chủ dự án, đừng tự thử cách nặng tay trên dữ liệu chung.

Ví dụ một giao diện Flutter dùng sẵn API này nằm ở [`23dthe1_pham_minh_vu/`](23dthe1_pham_minh_vu) (đổi địa chỉ bằng `--dart-define=BASE_URL=…`).

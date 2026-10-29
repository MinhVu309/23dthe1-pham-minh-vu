# Kịch bản demo SmartCheck (khoảng 8–10 phút)

Cần **hai máy Android**: máy A dùng tài khoản **Admin** (hiện QR, quản trị), máy B dùng **Employee** (chấm công). Có thể thay máy A bằng điện thoại khác hoặc máy tính bảng.

## 0. Chuẩn bị (làm trước khi vào phòng)

1. Cài APK lên cả hai máy, cấp quyền **Camera** và **Vị trí**, bật GPS.
2. Mở app một lần để "đánh thức" host miễn phí (request đầu có thể chậm 10–30 s).
3. Máy A: đăng nhập Admin → **Địa điểm** → mở "Văn phòng chính" → **chạm bản đồ đúng chỗ đang đứng** → Lưu. Nếu bỏ qua, mọi lần chấm công sẽ báo ngoài phạm vi.
4. Bật dữ liệu mẫu trên backend (`Seed:Demo=true`, xem README backend) để có sẵn tài khoản Manager/Employee và lịch sử cho bảng công, bản đồ, cảnh báo. Kiểm tra hộp thư `vupham010125@gmail.com` đang nhận được OTP (mọi tài khoản mẫu đều gửi OTP về đó).
5. Nếu máy B từng chấm công bằng máy khác: Admin → **Nhân viên** → ⋮ → **Đặt lại thiết bị**.

## 1. Đăng nhập 2 bước và 3 role (1,5 phút)

- Máy B: nhập email + mật khẩu → màn nhập **OTP** (đếm ngược, có "gửi lại") → vào trang **Nhân viên**.
- Máy A: đăng nhập Admin (hoặc nút **Google**) → trang **Quản trị**. Đăng nhập thử Manager để thấy trang quản lý khác.
- **Đăng ký mới:** màn Đăng nhập → Đăng ký → điền form → app chuyển sang màn **Xác minh email**; mã 6 số gửi về hộp thư vừa nhập, nhập đúng mới vào app. (Gõ nhầm email thì quay lại, sửa rồi đăng ký lại.)
- Tắt hẳn app rồi mở lại: vẫn còn đăng nhập.

## 2. QR động (1 phút)

- Máy A: **Điểm chấm công** → chọn địa điểm → QR toàn màn hình, có **đếm ngược 30 s** và tự đổi mã.
- Nói rõ: mã có hạn ~45 s; chụp ảnh QR rồi dùng lại sau 1 phút sẽ bị `QR_INVALID`.

## 3. Chấm công thành công: vị trí + khuôn mặt + QR (2 phút)

Máy B → **Chấm công** → **Vào ca**:
1. Thẻ **Vị trí** hiện toạ độ và sai số (vd. ±5 m).
2. Bấm "Quét mã QR" → màn **khuôn mặt**: đưa mặt vào khung oval, làm theo yêu cầu (**chớp mắt** hoặc **quay đầu**, ngẫu nhiên mỗi lần) → hiện dấu tích.
3. Màn **quét QR** → hướng vào máy A.
4. Kết quả: giờ chấm công, **khoảng cách** tới điểm, trạng thái **Đúng giờ / Đi trễ**.
5. Chấm **Ra ca** tương tự. Chấm lần nữa trong ngày → báo "đã chấm công" (409).

Chứng minh khuôn mặt thật sự chặn: mở lại màn khuôn mặt nhưng **không chớp mắt** (hoặc che camera) → hết 20 s báo "Chưa xác thực được", không quét QR được. Có hai người trong khung → báo "Chỉ để một khuôn mặt".

## 4. Ngoài phạm vi (1 phút)

Máy A: Admin → Địa điểm → đổi toạ độ sang nơi xa → Lưu. Máy B chấm công lại → thẻ đỏ **"Ngoài phạm vi chấm công"** kèm khoảng cách. Đổi toạ độ về như cũ.

## 5. Chống fake GPS (2 phút) – điểm mới của bài

Máy B (Android) bật vị trí giả lập tại **chính toạ độ địa điểm** (phải nằm trong bán kính, nếu không sẽ báo ngoài phạm vi trước):

- **Máy thật:** cài một app "Fake GPS", bật *Tuỳ chọn nhà phát triển → Chọn ứng dụng vị trí giả lập*, đặt toạ độ địa điểm.
- **Máy ảo (dùng adb):**
  ```bash
  adb shell appops set com.android.shell android:mock_location allow
  adb shell cmd location providers add-test-provider gps
  adb shell cmd location providers set-test-provider-enabled gps true
  adb shell cmd location providers set-test-provider-location gps --location <vĩ_độ>,<kinh_độ> --accuracy 5
  ```

Kết quả cần thấy:
1. Thẻ Vị trí hiện dòng đỏ **"Thiết bị đang báo vị trí giả lập"**.
2. Quét QR → thẻ đỏ **"Nghi ngờ gian lận"** + lý do *Thiết bị báo vị trí giả lập*. Lượt này **không** được ghi công.
3. Máy A: **Cảnh báo gian lận** → có mục mới "chưa xử lý" (kèm toạ độ, thiết bị) → bấm **Đã xử lý**.

Tắt giả lập sau khi xong:
```bash
adb shell cmd location providers remove-test-provider gps
adb shell appops set com.android.shell android:mock_location default
```

Các lớp chống gian lận khác (nói miệng, đều do server quyết định): sai số GPS bằng 0 hoặc > 100 m, đăng nhập sang **máy lạ** (mỗi tài khoản gắn một thiết bị, Admin có nút đặt lại), **di chuyển > 60 m/s** so với lần trước, trùng toạ độ y hệt người khác trong 2 phút (chỉ gắn cờ).

## 6. Quản trị và báo cáo (1,5 phút)

Máy A (Admin):
- **Bảng công**: tab *Theo ngày* (chọn ngày, lọc nhân viên, "Tải thêm") và tab *Theo tháng* (tổng ngày công, đi trễ, về sớm từng người).
- **Bản đồ chấm công**: vòng tròn bán kính địa điểm và các điểm chấm công; chạm một điểm xem chi tiết.
- **CRUD nhanh:** thêm một phòng ban, một nhân viên; xoá có hộp thoại xác nhận; xoá một mục đang được dùng (ví dụ phòng ban có nhân viên) thì server từ chối và app báo lỗi 409.
- Máy B (Employee): **Đơn nghỉ phép** → tạo đơn; máy A duyệt. **Lịch sử chấm công** → xem theo ngày và bảng công tháng.

## Câu hỏi thường gặp

- **Vì sao app không tự kiểm tra QR/vị trí?** Chạy trên máy người dùng nên không đáng tin; server giữ khoá ký QR và là nơi quyết định.
- **Vì sao khuôn mặt làm trước khi quét QR?** QR chỉ sống ~45 s, nên các bước chậm làm trước.
- **Làm sao biết GPS giả?** Android báo cờ `isMock` cho mỗi vị trí; app gửi nguyên cờ này lên server.
- **Chưa so khớp khuôn mặt?** Đúng, mới có kiểm tra người thật; so khớp vector cần model MobileFaceNet (xem README, phần Giới hạn).

## Sự cố thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Không nhận được OTP | Kiểm tra thư rác; bấm "Gửi lại" sau 30 s. Nếu host chặn SMTP thì OTP không gửi được. |
| Đăng nhập Google báo token không hợp lệ | Host chưa có `Google:ClientId` đúng, hoặc Google chưa áp dụng cài đặt (có thể mất đến vài giờ). |
| Request đầu rất chậm | Host miễn phí đang "ngủ"; chờ rồi thử lại. |
| Luôn báo ngoài phạm vi | Đổi toạ độ địa điểm về chỗ đang đứng (mục 0). |
| Camera không lên / vị trí không có | Cấp quyền trong Cài đặt; bật GPS; trên emulator cần cấu hình camera và vị trí ảo. |
| "Chấm công từ thiết bị chưa đăng ký" | Tài khoản đã gắn với máy khác; Admin → Nhân viên → Đặt lại thiết bị. |

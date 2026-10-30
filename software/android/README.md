# Khoa NAS 2.3 — Android

Ứng dụng Material 3 bằng Flutter, dùng logo GitHub của TranDangKhoaAutomation.
Tailscale và SMB nằm trong tiến trình ứng dụng qua Go/gomobile; không cần cài ứng dụng
Tailscale riêng, không tạo Android VPN và không chuyển lưu lượng của ứng dụng khác.

## Sử dụng

1. Trong **Kết nối**, chọn **Từ xa → Đăng nhập Tailscale** và tự xác thực trên trình duyệt.
   Đây là thiết bị Tailscale riêng của app; quản trị viên tailnet có thể cần duyệt thiết bị.
2. Chọn router từ danh sách thiết bị Tailscale. Nếu chưa có IP, danh sách tự mở sau khi kết nối; có thể dùng nút tìm thiết bị. Danh sách chỉ gồm các peer app được phép nhìn thấy, không quét dải IP hoặc tự xác nhận thiết bị đó là NAS. Nhập tài khoản/mật khẩu SMB rồi nhấn **Kết nối NAS**.
   Trong mạng nhà có thể chọn **Trong nhà** và dùng IP LAN, không cần Tailscale.
3. **Tệp** lấy danh sách share thật từ router. Hỗ trợ duyệt, tạo thư mục, đổi tên,
   xóa tệp/thư mục rỗng, tải lên và tải xuống qua bộ chọn tệp Android. Chuyển lưới/danh sách, xem ảnh/video trực tiếp, thumbnail và thời lượng video. Ảnh có nút cắt/xoay rồi lưu bản JPEG mới, giữ ảnh gốc.
4. **Ổ đĩa** dùng tài khoản LuCI riêng để xem phân vùng, gắn/mở khóa hoặc tháo gắn.
   Mật khẩu BitLocker được hỏi khi router chưa có khóa đã lưu. Ổ mới được nhận theo UUID.
5. **Sao lưu**: chọn thư mục Camera/Screenshots qua trình chọn Android, đặt nơi lưu và điều kiện mạng/sạc/lịch. Mặc định tắt, chỉ chạy sau khi lưu thiết lập và bật hoặc bấm Sao lưu ngay. [Hướng dẫn đầy đủ](../../docs/ANDROID-BACKUP.md).

Liên kết `smb://IP/SHARE` từ LuCI chỉ điền địa chỉ, không tự đăng nhập hoặc nhận mật khẩu
qua URL. App chỉ nhận IPv4 LAN hoặc Tailscale. Chế độ từ xa gọi trực tiếp TCP netstack của tsnet, không
tự chuyển sang mạng hệ thống nếu Tailscale chưa sẵn sàng.

Trạng thái Tailscale ở vùng dữ liệu riêng của app và bị loại khỏi Android Backup.
SMB chỉ lưu mật khẩu bằng Android Keystore khi chọn **Nhớ đăng nhập**; mật khẩu quản trị
không được lưu. Phiên LuCI chỉ nằm trong bộ nhớ. Gỡ app/xóa dữ liệu sẽ xóa kết nối đã lưu;
thiết bị Tailscale cũ có thể cần xóa riêng trong bảng quản trị tailnet.

Sao lưu nền dùng Android WorkManager 2.11.1 và phiên SMB riêng, không làm mất phiên xem tệp. Tệp tạm có thể gửi tiếp sau gián đoạn; hoàn tất mới đổi tên. Cấu hình sao lưu mã hóa AES-GCM bằng Android Keystore. Lịch có thể bị Android lùi; không chạy sau force-stop cho tới khi mở lại app. Sao lưu một chiều, không xóa ảnh điện thoại hoặc đồng bộ xóa. Chỉ mục đã hoàn tất không tự kiểm tra lại nếu người dùng xóa bản sao trên NAS.

Media dùng HTTP 127.0.0.1 có token ngẫu nhiên, hỗ trợ Range/HEAD/seek; đổi share/ngắt kết nối thu hồi URL. Cache thumbnail giới hạn 80 mục; mã hóa không biến URL thành đường dẫn công khai. Video/HEIC phụ thuộc codec Android. Tệp tải lên không ghi đè tệp trùng tên; tải lên thủ công bị hủy có thể còn tệp chưa hoàn tất.
Đăng nhập root chỉ dùng với router có module `nas.disks` trong repo này. Không mở SMB ra WAN.

## Build từ mã nguồn

Mã nguồn hiện hành là thư mục này; `apps/android` và APK v1 là bản lịch sử.
Toolchain đang dùng: Flutter 3.47.2/Dart 3.13.2, JDK 17, Android SDK 36, NDK 28.2.13676358,
Go **1.27.3**, gomobile/gobind **v0.0.0-20261011034528-197770444867**,
Tailscale **1.104.4**. Phiên bản được ghim trong `native/go.mod` và `native/build.py`.

Đặt `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_NDK_HOME` và thêm Go 1.27.3 vào `PATH`, sau đó:

```powershell
cd native
go test ./nasnet
python build.py
cd ..
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64
```

`native/build.py` biên dịch AAR cho arm64-v8a và x86_64. AAR/cache không được commit.
APK được tạo trong `build/app/outputs/flutter-apk/`. Bản arm64 dành cho điện thoại phổ biến;
x86_64 dùng cho LDPlayer. Android tối thiểu 8.0/API 26. Cấu hình hiện dùng khóa ký thử nghiệm
cục bộ của Android; muốn phát hành lâu dài cần thiết lập khóa ký riêng ngoài Git.

Lõi nhúng dùng [tsnet](https://tailscale.com/docs/features/tsnet) và
[go-smb2](https://github.com/hirochachacha/go-smb2/tree/v1.1.0).
Không nhúng auth key dùng chung hoặc thông tin đăng nhập vào mã nguồn/APK.

## Kiểm thử và giới hạn

Xem [báo cáo 2.3](../../reports/2026-10-30-android-2.3/README.md). Native: 10 kiểm thử đạt, một kiểm thử SMB tích hợp bỏ qua vì không có fixture. Flutter: 9 kiểm thử đạt; kiểm tra tiếp tục tệp dùng filesystem fixture, không thay cho kiểm thử mạng SMB thật. Router hiện không truy cập được SSH/HTTP, vì vậy chưa xác minh sao lưu nền, codec và tốc độ 2.3 với NAS thật/4G.

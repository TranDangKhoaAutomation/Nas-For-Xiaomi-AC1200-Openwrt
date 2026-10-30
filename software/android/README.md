# Khoa NAS 2 — Android

Ứng dụng Material 3 bằng Flutter, dùng logo GitHub của TranDangKhoaAutomation.
Tailscale và SMB nằm trong tiến trình ứng dụng qua Go/gomobile; không cần cài ứng dụng
Tailscale riêng, không tạo Android VPN và không chuyển lưu lượng của ứng dụng khác.

## Sử dụng

1. Trong **Kết nối**, chọn **Từ xa → Đăng nhập Tailscale** và tự xác thực trên trình duyệt.
   Đây là thiết bị Tailscale riêng của app; quản trị viên tailnet có thể cần duyệt thiết bị.
2. Nhập IP router hiện tại và tài khoản/mật khẩu SMB, nhấn **Kết nối NAS**.
   Trong mạng nhà có thể chọn **Trong nhà** và dùng IP LAN, không cần Tailscale.
3. **Tệp** lấy danh sách share thật từ router. Hỗ trợ duyệt, tạo thư mục, đổi tên,
   xóa tệp/thư mục rỗng, tải lên và tải xuống qua bộ chọn tệp Android.
4. **Ổ đĩa** dùng tài khoản LuCI riêng để xem phân vùng, gắn/mở khóa hoặc tháo gắn.
   Mật khẩu BitLocker được hỏi khi router chưa có khóa đã lưu. Ổ mới được nhận theo UUID.

Liên kết `smb://IP/SHARE` từ LuCI chỉ điền địa chỉ, không tự đăng nhập hoặc nhận mật khẩu
qua URL. App chỉ nhận IPv4 LAN hoặc Tailscale. Chế độ từ xa gọi trực tiếp TCP netstack của tsnet, không
tự chuyển sang mạng hệ thống nếu Tailscale chưa sẵn sàng.

Trạng thái Tailscale ở vùng dữ liệu riêng của app và bị loại khỏi Android Backup.
SMB chỉ lưu mật khẩu bằng Android Keystore khi chọn **Nhớ đăng nhập**; mật khẩu quản trị
không được lưu. Phiên LuCI chỉ nằm trong bộ nhớ. Gỡ app/xóa dữ liệu sẽ xóa kết nối đã lưu;
thiết bị Tailscale cũ có thể cần xóa riêng trong bảng quản trị tailnet.

Kết nối hoạt động khi app đang mở. Chưa có dịch vụ nền, đồng bộ tự động hoặc phát trực tiếp
video. Tệp tải lên không ghi đè tệp trùng tên; nếu hủy/mất mạng, kiểm tra tệp chưa hoàn tất.
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

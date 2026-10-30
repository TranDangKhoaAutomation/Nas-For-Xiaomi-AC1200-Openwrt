# Cài và cập nhật Khoa NAS

Tải [KhoaNAS-Ready.zip](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Ready.zip), giải nén toàn bộ rồi mở `BAT-DAU.txt`. Không cần sửa mã nguồn.

| Tệp | Dùng để làm gì |
|---|---|
| Cai-NAS.cmd + KhoaNAS-Router.tar.gz | Cài/cập nhật giao diện và dịch vụ NAS trên router |
| KhoaNAS-Android.apk | Android ARM64, gồm Samsung Galaxy A15 |
| KhoaNAS-Open.exe | Tiện ích Qt 6 mở thư mục NAS từ trình duyệt Windows |
| SHA256SUMS.txt | Đối chiếu tính toàn vẹn của các tệp |

**Phạm vi hỗ trợ router:** OpenWrt 25.12.6, ramips/mt7621, kernel 6.12.112. Đây là gói phần mềm bổ sung, không phải firmware Sysupgrade. Sai phiên bản thì bộ cài dừng; không ép cài module khác kernel. Cài dependency trên máy mới cần Internet và kho APK của firmware tương ứng.

## Router

1. Kết nối máy tính tới đúng router. Ưu tiên LAN khi cài/cập nhật dịch vụ mạng.
2. Chạy `Cai-NAS.cmd`, nhập IPv4 LAN hoặc Tailscale. Windows cần OpenSSH Client.
3. Kiểm tra danh tính máy chủ SSH rồi nhập mật khẩu quản trị trực tiếp khi được hỏi. Nếu máy chủ đổi khóa, đối chiếu thiết bị trước khi kết nối.
4. Sau `INSTALL_OK`, mở LuCI → **Các dịch vụ → NAS**. Bộ cài lưu bản sao cấu hình riêng trên router, kiểm tra checksum, dependency và module dm-zero trước khi triển khai.
5. Máy đã cấu hình: bộ cài được thiết kế giữ thiết lập theo UUID, tài khoản SMB, khóa và Tailscale. Máy mới/reset: chọn phân vùng ở **Ổ đĩa**, thêm thư mục ở **Chia sẻ**, thêm tài khoản và cấp quyền ở **Tài khoản SMB**.
6. BitLocker: nhập mật khẩu trên router và chọn tự mở khi cần. Dữ liệu trên ổ vẫn được mã hóa BitLocker; không xóa lớp mã hóa. Khóa tự mở chỉ lưu root-only trên router.

**Giới hạn kiểm chứng:** lần thử installer trên router thật ngày 30/10 làm gián đoạn SSH/HTTP khi khởi chạy lại Tailscale đang hoạt động. Mã hiện có kiểm tra tiến trình/dịch vụ và kiểm thử hồi quy để tránh gọi start lại. Chưa kiểm chứng lại trọn luồng trên router thật sau sửa vì thiết bị ở xa, không còn truy cập quản trị. Không coi bản đóng gói này là chứng nhận nâng cấp từ xa đã qua toàn bộ kiểm thử. Xem [báo cáo](../reports/2026-10-30-android-2.3/README.md).

Kiểm tra không thay đổi cấu hình: giải nén gói trên router rồi chạy `sh install.sh --check-only`. Lệnh này báo dependency thiếu; không tự sửa firmware.

## Android

1. Tải [APK ARM64](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Android.apk), mở trên điện thoại và cài đè để giữ dữ liệu. Không cần gỡ app trước.
2. **Kết nối → Từ xa → Đăng nhập Tailscale**. App có thiết bị Tailscale riêng và không dùng VPN hệ thống.
3. Chọn router từ danh sách thiết bị được tailnet cho phép nhìn thấy. Nếu chưa hiện, dùng nút tìm thiết bị sau khi trạng thái đã kết nối. Thiết bị xuất hiện không có nghĩa là đã có quyền SMB.
4. Nhập tài khoản/mật khẩu SMB. Chọn chia sẻ trong **Tệp**, chuyển lưới/danh sách, chạm ảnh/video để xem trực tiếp.
5. Sao lưu tự động và sửa ảnh: xem [hướng dẫn ảnh/video](ANDROID-BACKUP.md).

[APK x86_64 cho LDPlayer](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Android-x86_64.apk) tải riêng, không dùng cho Samsung ARM64. APK dùng cùng chứng thư thử nghiệm cục bộ với bản 2.0/2.1; chứng thư mới khác sẽ không cài đè được. Không đưa khóa ký vào repo.

## Windows

Chạy `KhoaNAS-Open.exe`, khai báo IP router được phép. Trong LuCI mở **NAS → Hướng dẫn kết nối → Windows → Mở thư mục NAS**. Nếu chưa cài tiện ích, sao chép đường dẫn UNC vào File Explorer. Truy cập từ xa cần Tailscale trên Windows. Hướng dẫn [kết nối và đổi mật khẩu SMB](REMOTE-ACCESS.md).

Bộ cài công khai không chứa mật khẩu, SSH private key, khóa BitLocker hoặc trạng thái Tailscale. Máy mới vẫn cần đăng nhập và chọn đúng ổ bằng thông tin riêng của bạn.

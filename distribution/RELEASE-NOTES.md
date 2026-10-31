Windows **Khoa NAS 1.1.0**: thêm tùy chọn **Khởi động cùng Windows** và một mục **Khoa NAS** cố định trong Start Menu.

- Bật/tắt trong cài đặt rồi lưu; chạy nền ở khay hệ thống khi đăng nhập, không tự mở cửa sổ hoặc ổ NAS.
- Mở nhiều lần dùng cùng một phiên/cửa sổ. Tệp tải/build chuyển về bản cài cố định; giữ các IP đã lưu khi cập nhật.
- Mặc định tắt trên máy mới, cập nhật giữ lựa chọn cũ. Không cần quyền quản trị, không tự bật Tailscale.
- Đã qua 11 kiểm thử Windows, gồm Run/checkbox, giữ cấu hình, IPC/khóa một phiên và kiểm tra liên kết.

Bộ cài gồm Android **2.3.1**: sửa Kết nối NAS xoay mãi, thêm Hủy và giới hạn chờ, bỏ kết quả trả muộn sau hủy. Cài đè để giữ dữ liệu. [Hướng dẫn Windows](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/blob/main/software/windows-open-nas/README.md).

**Lưu ý kết nối:** ngày 31/10 router vẫn ping Tailscale được nhưng các cổng 22/80/445 không truy cập được từ máy kiểm tra. Bản sửa Android kết thúc chờ đúng hạn; không khôi phục dịch vụ router. Chưa xác minh truy cập NAS thật sau sửa.

**Tải `KhoaNAS-Ready.zip`, giải nén rồi đọc `BAT-DAU.txt`.**

- Chạy `Cai-NAS.cmd`, nhập IP router và đăng nhập SSH khi được hỏi. Bộ cài tự kiểm tra phiên bản, checksum, dependency và dm-zero; giữ cấu hình/khóa/tài khoản đang có.
- Router được hỗ trợ: OpenWrt **25.12.6**, **ramips/mt7621**, kernel **6.12.112**. Gói này không phải firmware để flash bằng Sysupgrade.
- Android: cài `KhoaNAS-Android.apk`. Lấy thiết bị từ Tailscale trong app; khi chưa có IP, tự hiện danh sách sau đăng nhập. Chọn router rồi nhập tài khoản SMB. Không cần app VPN riêng.
- Lưới/danh sách, xem ảnh/video trực tiếp, thumbnail và thời lượng. Cắt/xoay ảnh rồi lưu JPEG mới, giữ ảnh gốc.
- Tab Sao lưu: chọn thư mục, ảnh/video, nơi lưu, lịch, Wi-Fi không tính phí/khi sạc. Mặc định tắt. Gửi tiếp tệp dở; sao lưu một chiều, không xóa ảnh điện thoại. Android có thể lùi lịch.
- `KhoaNAS-Android-x86_64.apk` dành cho LDPlayer; điện thoại Samsung dùng APK ARM64 mặc định.
- Windows: `KhoaNAS-Open.exe` cài tiện ích Qt 6 cho nút mở thư mục từ LuCI.
- Menu NAS có bốn tab: Ổ đĩa, Chia sẻ, Tài khoản SMB, Hướng dẫn kết nối.

SHA-256 của từng tệp nằm trong `SHA256SUMS.txt`. Mật khẩu, khóa BitLocker/SSH và trạng thái Tailscale không được đưa vào bộ cài công khai. Cài mới/reset vẫn cần chọn đúng ổ và đăng nhập bằng thông tin riêng; không cần sửa mã nguồn.

**Kiểm thử:** Windows 11 đạt, Android native 13 đạt + 1 SMB fixture bỏ qua, Flutter 12 chức năng đạt + 1 test minh họa opt-in, đóng gói 4 đạt. Lần thử installer thật ngày 30/10 làm mất truy cập SSH/HTTP khi gọi start Tailscale đang chạy. Mã router đã bổ sung kiểm tra process/status và hồi quy không gọi start lại, nhưng chưa kiểm chứng trọn luồng nâng cấp lại trên router thật vì thiết bị ở xa. Sao lưu nền, codec/streaming NAS thật, 4G và tốc độ sau tối ưu còn cần xác minh. Xem báo cáo trong repo trước khi nâng cấp từ xa.

APK cùng chứng thư thử nghiệm cục bộ với 2.0/2.1/2.3.0; cài đè giữ dữ liệu. Chưa cài 2.3.1 lên Samsung vì điện thoại đã ngắt USB. Bộ công khai không chứa thông tin đăng nhập; cài mới vẫn cần chọn ổ và đăng nhập bằng thông tin riêng.

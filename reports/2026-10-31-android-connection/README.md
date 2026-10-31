# Android 2.3.1 — xử lý Kết nối NAS xoay mãi

Người dùng xác nhận đang chọn **100.114.53.95 — Từ xa (Tailscale)**. Đây là địa chỉ/chế độ phù hợp với NAS hiện tại.

## Quan sát ngày 31/10/2026

- Từ Windows đang đăng nhập Tailscale: router báo online, ping qua DERP Hong Kong khoảng 49 ms; chưa thiết lập direct.
- TCP IPv4 22, 80 và 445 đều timeout trong probe 4 giây. IPv6 Tailscale tương ứng trả connection refused trên ba cổng đó.
- Windows ở mạng 192.168.2.x, không kết nối trực tiếp LAN router. Peer không có subnet route hoặc Tailscale SSH host key trong status đã đọc.
- Samsung xuất hiện qua ADB trong chốc lát rồi ngắt USB trước khi có APK mới; chưa cài 2.3.1 lên Samsung trong lần này.

Những quan sát trên cho thấy đường tới dịch vụ NAS chưa sử dụng được từ máy kiểm tra. Trạng thái online/ping Tailscale không chứng minh SMB hoạt động. Chưa lấy được log bên trong router để xác định đầy đủ nguyên nhân. Không suy ra mật khẩu SMB sai khi chưa kết nối được cổng dịch vụ. Trạng thái đường mạng của điện thoại chưa đo riêng.

Sự cố mất truy cập quản trị sau installer ngày 30/10 đã được ghi trong [báo cáo trước](../2026-10-30-android-2.3/README.md). Chưa thể xác minh khôi phục vì router ở xa. Bản sửa app không được coi là khôi phục router.

## Sửa trong app

- Giới hạn mỗi bước native Connect/Mount 15 giây và toàn bộ luồng Kết nối NAS 35 giây, gồm cả chờ khóa thao tác.
- Hiển thị đang liên hệ NAS hay mở thư mục; có nút **Hủy kết nối** luôn thấy trong lúc chờ.
- Hủy/timeout đóng socket đang chờ và hủy context qua bridge, không phải chỉ giấu spinner.
- Kết quả native trả muộn sau khi hủy không khôi phục phiên, tự mount hoặc chuyển trang. Chưa đăng nhập Tailscale trong app sẽ có thông báo trước khi thử SMB.
- Giữ yêu cầu SMB signing, kiểm tra IP/allowlist và chế độ từ xa không fallback sang mạng ngoài Tailscale.

## Kiểm thử

| Phần | Kết quả |
|---|---|
| Native Go | 13 đạt, 1 SMB fixture bỏ qua |
| Hủy khi đang chờ mutex | Trả ngay, không phải chờ mutex được nhả |
| Hủy khi socket đang chờ đọc | Socket bị ngắt |
| Socket sau bước thành công | Còn hoạt động, không bị cancel cleanup đóng nhầm |
| Hủy phiên cũ / phiên mới | Finish của phiên cũ không xóa phiên đang hoạt động |
| Flutter | 12 kiểm thử chức năng đạt + 1 test minh họa opt-in không chạy render nếu không có biến output |
| Native trả thành công muộn | Bị bỏ qua sau hủy; không tự mount |
| Chờ không trả kết quả | Sau giới hạn 35 giây bỏ trạng thái bận và báo lỗi |
| Nút Hủy | Bỏ spinner, thông báo đã hủy và bỏ qua trả lời muộn |
| Phân tích Flutter | Không có vấn đề |
| NAS thật sau sửa | Chưa xác minh kết nối được vì cổng dịch vụ không phản hồi |

## Cài APK

Mở [link APK ARM64 mới nhất](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Android.apk) **trên Samsung**, tải xong mở tệp và chọn cập nhật/cài đè. APK cùng chữ ký với các bản trước; không cần gỡ app hoặc xóa dữ liệu. Tải APK trong trình duyệt Windows không tự cài vào điện thoại.

Sau khi cài, mở Khoa NAS, đăng nhập Tailscale **trong app**, chọn router, nhập tài khoản/mật khẩu SMB. Nếu vẫn không phản hồi, kiểm tra dịch vụ router qua mạng LAN khi có người tại chỗ; không format ổ, gỡ BitLocker hay reset mật khẩu chỉ vì lỗi timeout.

[Hướng dẫn Android](../../software/android/README.md) · [Cài đặt và cập nhật](../../docs/INSTALL.md).

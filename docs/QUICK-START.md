# Bắt đầu nhanh — cấu hình hiện tại

## Dùng NAS từ xa

1. Cài Tailscale trên Windows/Android, đăng nhập đúng tailnet và bật kết nối.
2. Mở share `\\100.114.53.95\BITLOCKER` bằng user `nas` và mật khẩu SMB. Windows có thể map thành ổ trong This PC; Android thêm kết nối SMB trong ứng dụng quản lý tệp.
3. Muốn quản lý/mở khóa, vào [LuCI → Hệ thống → Ổ đĩa](http://100.114.53.95/cgi-bin/luci/admin/system/disks).

**[Hướng dẫn chi tiết Windows và Android](REMOTE-ACCESS.md)** có bảng thông số, cách map ổ, phân biệt các loại mật khẩu và xử lý lỗi.

## Trạng thái tham chiếu 30/10/2026

- BitLocker 100 GiB đã gắn **đọc/ghi** sau CHKDSK và cắm lại router. Tự mở sau reboot đã kiểm chứng ngày 29/10 ở chế độ chỉ đọc.
- NTFS DangKhoa 831.5 GiB đã hết dirty và gắn đọc/ghi; cả hai share đã thử tạo/đọc/xóa qua SMB.
- Router Tailscale `100.114.53.95`; sau đổi/reset router phải lấy IP mới.

## Dựng/cài lại giao diện trên router

Đọc [bộ mã và hướng dẫn cài LuCI Disk Manager](../router/luci-disk-manager/README.md), [dm-zero đúng kernel](../releases/dm-zero/6.12.112/README.md) và [trạng thái hiện tại](CURRENT-STATE.md).

Chọn driver và module đúng firmware/kernel. Nhập khóa trên router sau khi cài, không lưu bí mật vào Git. Khi thay ổ, quét lại, đối chiếu UUID và cấu hình từng phân vùng. Snapshot NAS1/NAS2/PRIVATE cũ là lịch sử.

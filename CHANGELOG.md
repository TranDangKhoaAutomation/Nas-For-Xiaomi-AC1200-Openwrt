# Changelog

## 2026-10-29
- Thêm LuCI Disk Manager tổng quát: quét ổ thực tế, thiết lập/mount/unlock theo UUID, xử lý mật khẩu nền và key root-only.
- Thêm Việt/Anh theo LuCI, bản dịch Tailscale/nút dịch vụ và sửa chung sidebar Material che nội dung.
- Cập nhật dm-zero cho kernel 6.12.112/OpenWrt 25.12.6, kèm nguồn, APK và hash kiểm chứng.
- Xác minh tự mở BitLocker chỉ đọc sau reboot, SMB qua LAN và IP Tailscale.
- Thêm hướng dẫn truy cập NAS **từ xa** trên Windows và Android; ghi rõ NTFS lớn chưa gắn, Android/4G chưa thử thực tế.
- Cập nhật README/trạng thái hiện tại, lưu README 12/10 vào lịch sử và giữ các tệp cục bộ ngoài phạm vi thay đổi.

## 2026-09-26
- Tổng hợp repo NAS hoàn chỉnh.
- Thêm public sanitized backup.
- Thêm source + release Windows/Android.
- PC app chuyển sang Windows WNet API.
- Thêm timeout/watchdog tránh treo UI.
- Thêm persistent mapping vào This PC.
- Thêm hướng dẫn Error 86/1219/1223.
- Xác nhận PRIVATE auto-unlock đang bật trên hệ thống tham chiếu.

## 2026-09-25
- Multi-volume manager NAS1/NAS2/PRIVATE.
- Watchdog self-heal.
- VeraCrypt lock/unlock.
- KSMBD chỉ chạy khi storage thật tồn tại.
- Fix dirty NTFS.
- Test SMB RW qua Tailscale.

## 2026-09-24
- Tạo bộ firmware/config backup OpenWrt 25.12.5.
- Thu thập build, MTD, partition, package metadata và recovery images.
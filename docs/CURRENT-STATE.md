# Trạng thái hệ thống đã xác minh — 29/10/2026

| Thành phần | Trạng thái |
|---|---|
| Router | Xiaomi Mi Router 3G, MT7621, OpenWrt 25.12.6, kernel 6.12.112 |
| Địa chỉ | LAN 192.168.1.1; Tailscale 100.114.53.95, tên openwrt |
| Quản lý storage | Hệ thống → Ổ đĩa; mã generic theo UUID trong router/luci-disk-manager |
| Ổ USB | Khoảng 1 TB; bridge nhận dạng Generic External |
| Vùng 16 MiB | Chưa nhận dạng filesystem/UUID; không mount |
| DangKhoa 831.5 GiB | NTFS, UUID A8E46416E463E4D2, chưa gắn do dirty |
| Data-DangKhoa 100 GiB | BitLocker UUID 1a518101-853b-45d0-ae99-beac1d47c63a, tự mở sau reboot, NTFS3 chỉ đọc tại /mnt/bitlocker |
| SMB | BITLOCKER chỉ đọc, user nas, không guest. Share DANGKHOA tồn tại nhưng volume chưa mount |
| Khóa tự mở | Root-only tại /etc/nas-disks/keys; không xuất khóa vào repo |
| Dịch vụ | nas-disks S96, hotplug, cron mỗi phút; KSMBD, Tailscale, RPC và uHTTPd hoạt động |
| Remote SMB | Windows TCP 445 qua interface Tailscale và Test-Path tới BITLOCKER=True |
| Firewall | Tailnet cho quản trị/SMB; WAN không mở 22/80/445; fw4 check đạt |
| Giao diện | Việt/Anh theo LuCI; Material sidebar không còn che nội dung |

Reboot thật đã kiểm chứng, không chạy mount/unlock thủ công sau boot. Chưa thử ghi vì volume RO; chưa thử Android, 4G/5G độc lập hoặc thay ổ vật lý trong phiên này.

Truy cập: [Windows/Android từ xa](REMOTE-ACCESS.md). Chi tiết: [báo cáo triển khai](../reports/2026-10-29-disk-manager/README.md).

Các báo cáo ngày 25–26/09 và 12/10, snapshot router/current hoặc UUID NAS1/NAS2/PRIVATE là lịch sử. Không restore trực tiếp chúng cho cấu hình hiện tại.

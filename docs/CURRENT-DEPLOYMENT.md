# Triển khai hiện tại — 29/10/2026

Xiaomi Mi Router 3G, OpenWrt 25.12.6, kernel 6.12.112. Xem [trạng thái đã xác minh](CURRENT-STATE.md).

## Thành phần đang dùng

- Mã nguồn: [router/luci-disk-manager](../router/luci-disk-manager/README.md).
- `/usr/sbin/nas-disks-manager`, `nas-disks-job`, `nas-disks-scan`.
- `/etc/init.d/nas-disks` (S96), `/etc/hotplug.d/block/96-nas-disks`, cron reconcile mỗi phút.
- Cấu hình theo UUID: `/etc/config/nas_disks`.
- RPC object `nas.disks`; LuCI tại `/cgi-bin/luci/admin/system/disks`.
- Khóa root-only tại `/etc/nas-disks/keys/`, không có trong snapshot public.
- Gói dm-zero [6.12.112](../releases/dm-zero/6.12.112/README.md), tự nạp khi boot.
- Catalog Việt/Anh và Material layout fix; bản dịch chính thức KSMBD/Firewall/Attended Sysupgrade/Package Manager.

Manager BitLocker cố định UUID và trang BitLocker trước đó đã được thay bằng manager tổng quát. Thư mục `router/current` giữ snapshot lịch sử, không phải bộ deploy hiện hành.

Tailscale: `100.114.53.95`; KSMBD template bind LAN và tailscale0, firewall tailnet cho TCP 22/80/445. Hướng dẫn [truy cập từ xa trên Windows/Android](REMOTE-ACCESS.md).

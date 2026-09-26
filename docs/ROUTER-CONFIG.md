# Router configuration snapshot

Thư mục router/current là snapshot file đang chạy, lấy trực tiếp từ router ngày 2026-09-26.

## Mapping

- usr-sbin-nas-storage-manager -> /usr/sbin/nas-storage-manager
- etc-init.d-nas-storage -> /etc/init.d/nas-storage
- etc-hotplug.d-block-95-nas-storage -> /etc/hotplug.d/block/95-nas-storage
- etc-config-ksmbd -> /etc/config/ksmbd
- etc-config-firewall -> /etc/config/firewall
- usr-sbin-nas-private-autounlock -> /usr/sbin/nas-private-autounlock
- usr-sbin-nas-private-autounlock-setup -> /usr/sbin/nas-private-autounlock-setup
- usr-sbin-nas-private-autounlock-disable -> /usr/sbin/nas-private-autounlock-disable
- etc-init.d-nas-private-autounlock -> /etc/init.d/nas-private-autounlock

## Trước khi overwrite

1. Backup file hiện tại.
2. So sánh network/firewall với hệ thống của bạn.
3. Không copy credential từ máy khác.
4. Copy từng block.
5. Set executable bit đúng cho script.
6. Restart service.
7. Chạy status và regression SMB.

Snapshot không chứa SMB password database, VeraCrypt keyfile hoặc Tailscale state.

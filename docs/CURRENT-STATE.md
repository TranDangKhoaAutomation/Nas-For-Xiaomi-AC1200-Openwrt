# Trạng thái hệ thống đã xác minh

Snapshot kiểm tra ngày 2026-09-26:

- Router: Xiaomi Mi Router 3G
- Board: xiaomi,mi-router-3g
- SoC: MediaTek MT7621
- OpenWrt: 25.12.5 r33051-f5dae5ece4
- Kernel: 6.12.94
- Target: ramips/mt7621
- Tailscale IPv4 hiện tại: 100.91.1.101
- KSMBD: running
- SMB user: nas
- Password SMB: không lưu trong repo

## Storage

| Vùng | Thiết bị | Mount | FS | Share | Trạng thái |
|---|---|---|---|---|---|
| NAS1 | /dev/sda1 | /mnt/nas | NTFS / ntfs3 | NAS1 | RW |
| NAS2 | /dev/sda2 | /mnt/nas2 | NTFS / ntfs3 | NAS2 | RW |
| PRIVATE | /dev/sda3 -> /dev/mapper/private | /mnt/private | VeraCrypt/TCRYPT + NTFS | PRIVATE | RW khi unlock |

NAS1 và NAS2 từng được xác định bằng UUID:
- NAS1: 01DC8764756E6240
- NAS2: 78F6F2BBF6F278A8

PRIVATE được xác định là partition 3 trên cùng physical disk chứa đúng hai volume NAS1/NAS2.

## PRIVATE auto-unlock

Snapshot hiện tại có:
- /root/.nas-private-passphrase: tồn tại;
- quyền file: root-only;
- service nas-private-autounlock: enabled.

Nội dung keyfile không được export.

Auto-unlock tiện cho reboot nhưng giảm bảo mật vật lý: nếu ai có quyền root hoặc lấy được router flash thì secret có thể bị lộ.

## Network

UNC hiện dùng qua Tailscale:

    \\100.91.1.101\NAS1
    \\100.91.1.101\NAS2
    \\100.91.1.101\PRIVATE

Firewall:
- source tailscale -> TCP 445: ACCEPT;
- source wan -> TCP 445: REJECT.

Không port-forward SMB 445 ra Internet.

## Package chính đang dùng

- block-mount
- cryptsetup
- kmod-fs-ksmbd
- kmod-fs-ntfs3
- kmod-usb-storage
- kmod-usb-xhci-hcd
- kmod-usb-xhci-mtk
- kmod-usb3
- ksmbd-server
- ntfs-3g
- ntfs-3g-utils
- smartmontools
- tailscale

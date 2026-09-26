# NAS for Xiaomi AC1200 / Mi Router 3G on OpenWrt

Repo này là bộ triển khai NAS hoàn chỉnh cho Xiaomi Mi Router 3G / AC1200 chạy OpenWrt, được tổng hợp từ hệ thống đã cấu hình và kiểm thử thực tế.

Nó bao gồm:
- firmware/recovery backup đã làm sạch secret;
- multi-volume storage manager;
- KSMBD/SMB;
- Tailscale remote access;
- PRIVATE VeraCrypt;
- auto-mount/watchdog/self-heal;
- hướng dẫn backup/restore;
- hướng dẫn khắc phục toàn bộ lỗi đã gặp;
- source + release app Windows;
- source + APK Android;
- config snapshot, script vận hành, report và checksum.

> Repo là PUBLIC. Backup gốc có mật khẩu, /etc/shadow, Dropbear host key và Wi-Fi key không được đưa lên. File trong backups/public là bản SANITIZED.

## 1. Hệ thống tham chiếu

| Thành phần | Giá trị |
|---|---|
| Router | Xiaomi Mi Router 3G / AC1200 |
| SoC | MediaTek MT7621 |
| OpenWrt | 25.12.5 r33051-f5dae5ece4 |
| Kernel | 6.12.94 |
| Target | ramips/mt7621 |
| Board | xiaomi,mi-router-3g |
| HDD | HGST HTS721010A9E630, 1 TB, 7200 RPM |
| Partition table | MBR/DOS |
| SMB server | KSMBD |
| SMB user | nas |
| Remote access | Tailscale |
| PRIVATE encryption | VeraCrypt/TCRYPT + NTFS |
| Windows client | Khoa-NAS-PC |
| Android client | Flutter Khoa NAS |

Địa chỉ Tailscale cá nhân được thay bằng <TAILSCALE_IP> trong tài liệu public.

## 2. Layout storage

~~~text
HGST 1 TB
├─ /dev/sda1  NAS1     ~831.5 GiB NTFS  -> /mnt/nas
├─ /dev/sda2  NAS2     ~50 GiB    NTFS  -> /mnt/nas2
└─ /dev/sda3  PRIVATE  ~50 GiB VeraCrypt
      └─ /dev/mapper/private -> NTFS -> /mnt/private
~~~

UUID của hệ thống tham chiếu:
- NAS1: 01DC8764756E6240
- NAS2: 78F6F2BBF6F278A8

Manager tìm NAS1/NAS2 bằng UUID và xác định PRIVATE là partition 3 trên đúng physical disk chứa cả hai UUID, vì vậy không phụ thuộc cố định vào tên sda/sdb.

## 3. Share SMB

~~~text
NAS1     -> /mnt/nas
NAS2     -> /mnt/nas2
PRIVATE  -> /mnt/private
~~~

Remote qua Tailscale:

~~~text
\\<TAILSCALE_IP>\NAS1
\\<TAILSCALE_IP>\NAS2
\\<TAILSCALE_IP>\PRIVATE
~~~

PRIVATE chỉ xuất hiện khi VeraCrypt mapper đang mở và filesystem đã mount thật.

## 4. Kiến trúc remote

~~~text
PC / Android
    |
    +-- Tailscale encrypted tunnel
            |
            +-- OpenWrt router
                  +-- firewall ACCEPT TCP/445 từ tailscale
                  +-- firewall REJECT TCP/445 từ WAN
                  +-- KSMBD
                  +-- NAS1 / NAS2 / PRIVATE
~~~

Không port-forward SMB TCP/445 trực tiếp ra Internet.

## 5. Package đang dùng

~~~sh
apk update
apk add \
  block-mount cryptsetup \
  kmod-fs-ksmbd kmod-fs-ntfs3 \
  kmod-usb-storage kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb3 \
  ksmbd-server ntfs-3g ntfs-3g-utils smartmontools tailscale
~~~

## 6. Storage manager

File chính: scripts/router/nas-storage-manager

Chức năng:
- auto-detect NAS1/NAS2 bằng UUID;
- xác định PRIVATE theo physical disk;
- mount NTFS3;
- không format;
- không tự repair;
- không force dirty NTFS RW;
- fallback read-only nếu RW fail;
- chỉ tạo KSMBD share khi mount thật tồn tại;
- tự gỡ share khi disk mất;
- PRIVATE chỉ share khi mapper active;
- procd watchdog + reconcile;
- safe eject.

Lệnh:

~~~sh
/usr/sbin/nas-storage-manager status
/usr/sbin/nas-storage-manager reconcile
/usr/sbin/nas-storage-manager unlock-private
/usr/sbin/nas-storage-manager lock-private
/usr/sbin/nas-storage-manager eject
~~~

## 7. PRIVATE VeraCrypt

Manual unlock:

~~~sh
/usr/sbin/nas-storage-manager unlock-private
~~~

Auto-unlock:

~~~sh
/usr/sbin/nas-private-autounlock-setup
~~~

Tắt auto-unlock:

~~~sh
/usr/sbin/nas-private-autounlock-disable
~~~

Auto-unlock lưu passphrase tại /root/.nas-private-passphrase với mode 0600. Đây là lựa chọn tiện lợi nhưng giảm mức bảo vệ nếu attacker lấy được cả router + HDD hoặc có root trên router.

Manager chính không chứa passphrase; auto-unlock là subsystem riêng.

## 8. Backup

Bản public:
backups/public/OpenWrt_Backup_Xiaomi_Mi_Router_3G_2026-09-24_SANITIZED.zip

Nó chứa:
- sysupgrade image;
- initramfs/kernel/rootfs recovery files;
- build metadata;
- package list;
- partition/MTD metadata;
- config archive đã loại /etc/shadow + Dropbear host keys;
- UCI key/password đã REDACTED;
- checksum.

Backup gốc private không upload. SHA-256 lịch sử:
006b2b8a4a36236558a7db954d43c772bebf43e7794bc467a4468d0e6ba0a143

Chi tiết: docs/BACKUP-RESTORE.md

## 9. Windows app

Source:
software/pc/khoa_nas_pc.py

Release:
software/releases/Khoa-NAS-PC.exe

Tính năng:
- đăng nhập SMB;
- map persistent thành Network Drive trong This PC;
- tự nhận mapping cũ;
- chỉ unmap khi người dùng nhấn Xóa khỏi This PC;
- browse/upload/download/create/rename/delete;
- timeout/watchdog;
- Windows WNet API để truyền credential trực tiếp.

Bản cũ từng dùng net use với dấu * và gây lỗi interactive/cancel dù password nhập đúng. Bản mới đã bỏ cách đó.

Lưu ý: PyInstaller EXE unsigned có thể bị Windows Smart App Control chặn. Xem docs/CLIENT-APPS.md.

## 10. Android app

Source:
software/android/

APK:
software/releases/Khoa-NAS-Android-v1.0.0.apk

Đã kiểm:
- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: All tests passed.

Android cần Tailscale đang kết nối tailnet nếu dùng SMB remote.

## 11. Các lỗi đã gặp

Đã có hướng dẫn xử lý:
- HDD không nhận sau reboot;
- disk nhận nhưng thư mục/share không mở;
- share path thừa /sd;
- dirty NTFS;
- ntfsfix / chkdsk;
- USB reset / Buffer I/O error / device offlined;
- nguồn HDD 2.5" 7200 RPM;
- tên file tiếng Việt;
- KSMBD không chạy/share rỗng;
- PRIVATE không xuất hiện;
- Tailscale ping được nhưng SMB không được;
- Error 86 / 1326;
- Error 1219 credential conflict;
- Error 1223 operation canceled;
- Windows cached SMB credential;
- app Windows treo nút Kết nối;
- Smart App Control chặn EXE;
- Flutter Windows cần symlink/Developer Mode;
- Kotlin cross-drive incremental cache;
- tốc độ SMB thấp;
- phục hồi firmware.

Xem docs/TROUBLESHOOTING.md.

## 12. Cấu trúc repo

~~~text
.
├─ README.md
├─ SECURITY.md
├─ CHANGELOG.md
├─ docs/
├─ scripts/
│  ├─ router/
│  └─ windows/
├─ config/
│  ├─ snapshots/
│  └─ templates/
├─ backups/
│  └─ public/
├─ reports/
├─ software/
│  ├─ pc/
│  ├─ android/
│  └─ releases/
└─ SHA256SUMS.txt
~~~

## 13. Tài liệu

- docs/QUICK-START.md — cấu hình nhanh
- docs/BACKUP-RESTORE.md — backup/download/restore
- docs/TROUBLESHOOTING.md — tất cả lỗi/fix
- docs/SECURITY.md — security model
- docs/CLIENT-APPS.md — Windows/Android
- docs/RECOVERY.md — firmware/recovery
- docs/OPERATIONS.md — vận hành hằng ngày
- docs/SMB-PASSWORD.md — đổi password và credential Windows

## 14. Trạng thái kiểm thử

Đã PASS:
- NAS1 SMB RW
- NAS2 SMB RW
- PRIVATE SMB RW khi unlock
- TCP/445 qua Tailscale
- WAN 445 REJECT theo firewall
- watchdog self-heal share
- PC app error handling + WNet mapping logic
- Android analyze/test

Báo cáo lịch sử sanitized: reports/Bao-Cao-Hoan-Tat-Router-NAS.md

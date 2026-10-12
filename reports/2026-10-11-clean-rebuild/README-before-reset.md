# NAS for Xiaomi Mi Router 3G / OpenWrt

Bộ repo này ghi lại đầy đủ hệ thống NAS đã triển khai và kiểm thử trên Xiaomi Mi Router 3G chạy OpenWrt 25.12.5: USB storage, NTFS, KSMBD, Tailscale remote SMB, PRIVATE VeraCrypt, watchdog/self-heal, backup/recovery, app Windows + Android và các lỗi thực tế đã gặp.

> Quan trọng: tên repo có “Xiaomi AC1200”, nhưng phần cứng đã xác minh của bộ backup này là Xiaomi Mi Router 3G, board xiaomi,mi-router-3g, SoC MT7621. Không flash firmware này cho model khác chỉ vì cùng nhãn AC1200.

## 1. Trạng thái hiện tại đã xác minh

| Hạng mục | Trạng thái |
|---|---|
| Router | Xiaomi Mi Router 3G |
| Board | xiaomi,mi-router-3g |
| SoC | MediaTek MT7621 |
| OpenWrt | 25.12.5 r33051-f5dae5ece4 |
| Kernel | 6.12.94 |
| Target | ramips/mt7621 |
| SMB server | KSMBD |
| Tailscale | running |
| Tailscale IPv4 snapshot | 100.91.1.101 |
| NAS1 | /dev/sda1 -> /mnt/nas, NTFS3 RW |
| NAS2 | /dev/sda2 -> /mnt/nas2, NTFS3 RW |
| PRIVATE | /dev/sda3 -> /dev/mapper/private -> /mnt/private, VeraCrypt/TCRYPT + NTFS3 RW |
| SMB shares | NAS1, NAS2, PRIVATE |
| SMB user | nas |
| WAN TCP/445 | REJECT |
| Tailscale TCP/445 | ACCEPT |
| PRIVATE auto-unlock | enabled trong snapshot hiện tại; keyfile không có trong repo |

Remote SMB hiện dùng:

    \\100.91.1.101\NAS1
    \\100.91.1.101\NAS2
    \\100.91.1.101\PRIVATE

Không expose SMB trực tiếp ra Internet. Remote access đi qua Tailscale.

## 2. Cấu trúc repo

    .
    ├─ README.md
    ├─ docs/
    │  ├─ CURRENT-STATE.md
    │  ├─ QUICK-START.md
    │  ├─ BACKUP-RESTORE.md
    │  ├─ STORAGE-VERACRYPT.md
    │  ├─ ROUTER-CONFIG.md
    │  ├─ OPERATIONS.md
    │  ├─ APPS.md
    │  ├─ TROUBLESHOOTING.md
    │  ├─ RECOVERY.md
    │  ├─ SECURITY.md
    │  └─ history/
    ├─ router/
    │  ├─ current/
    │  └─ helpers/
    ├─ apps/
    │  ├─ windows/src/
    │  └─ android/
    ├─ releases/
    │  ├─ Khoa-NAS-PC.exe
    │  ├─ Khoa-NAS-Android-v1.0.0.apk
    │  └─ SHA256SUMS.txt
    ├─ backups/
    │  └─ public/
    │     └─ OpenWrt_Backup_Xiaomi_Mi_Router_3G_2026-09-24_SANITIZED.zip
    └─ firmware/
       └─ README.md

## 3. Kiến trúc storage

HDD 1 TB hiện được tổ chức:

- NAS1: khoảng 831.5 GiB, NTFS, mount /mnt/nas.
- NAS2: khoảng 50 GiB, NTFS, mount /mnt/nas2.
- PRIVATE: khoảng 50 GiB, VeraCrypt/TCRYPT trên partition 3; khi unlock mapper là /dev/mapper/private, NTFS mount /mnt/private.

Storage manager hiện làm các việc:

- tìm NAS1/NAS2 theo UUID và quan hệ physical disk, không tin tuyệt đối /dev/sdaX;
- tự reconcile qua procd/watchdog;
- xử lý hotplug;
- không format;
- không tự repair filesystem;
- không force dirty NTFS RW;
- khi storage mất thì cleanup mount/share;
- chỉ bật/expose KSMBD khi có storage thật;
- PRIVATE bị gỡ khỏi KSMBD khi locked và được thêm lại khi mapper xuất hiện.

## 4. Kiến trúc network

- LAN có thể truy cập SMB khi KSMBD interface phù hợp.
- Remote SMB đi qua Tailscale.
- Firewall ACCEPT TCP/445 từ zone Tailscale.
- Firewall REJECT TCP/445 từ WAN.
- Không port-forward SMB 445 ra Internet.

## 5. PRIVATE VeraCrypt

PRIVATE dùng /dev/sda3 và được mở thành /dev/mapper/private.

Có hai cách vận hành:

1. Manual unlock: bảo mật vật lý tốt hơn; reboot xong phải nhập passphrase.
2. Auto-unlock: tiện hơn; secret root-only được lưu trên router flash.

Snapshot hiện tại đang bật auto-unlock. Nội dung /root/.nas-private-passphrase không được export vào repo.

Đây là trade-off rõ ràng: nếu ai đó có quyền root hoặc lấy được flash router thì secret auto-unlock có thể bị lộ.

## 6. Cài nhanh từ OpenWrt đang chạy

Xem chi tiết tại docs/QUICK-START.md.

OpenWrt 25.12 sử dụng apk:

    apk update
    apk add block-mount cryptsetup kmod-fs-ksmbd kmod-fs-ntfs3 \
      kmod-usb-storage kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb3 \
      ksmbd-server ntfs-3g ntfs-3g-utils smartmontools tailscale

Tailscale:

    /etc/init.d/tailscale enable
    /etc/init.d/tailscale start
    tailscale up

KSMBD user:

    ksmbd.adduser -a nas

Đổi mật khẩu:

    ksmbd.adduser -u nas
    /etc/init.d/ksmbd restart

Không ghi mật khẩu SMB vào script hoặc repo.

## 7. Snapshot router

Thư mục router/current chứa snapshot file đang vận hành, lấy trực tiếp từ router ngày 2026-09-26:

- nas-storage-manager;
- init service nas-storage;
- block hotplug 95-nas-storage;
- KSMBD config;
- firewall config;
- PRIVATE auto-unlock scripts;
- status snapshot.

Cố ý không có:

- /etc/ksmbd/ksmbdpwd.db;
- /root/.nas-private-passphrase;
- Tailscale state/auth key;
- /etc/shadow;
- SSH private keys.

Xem docs/ROUTER-CONFIG.md.

## 8. Backup đầy đủ nhưng an toàn cho repo public

Backup gốc riêng tư có /etc/shadow, SSH host private key và Wi-Fi key/password nên không được đẩy nguyên xi lên GitHub public.

Repo thay bằng:

    backups/public/OpenWrt_Backup_Xiaomi_Mi_Router_3G_2026-09-24_SANITIZED.zip

Bản public sanitized vẫn có:

- sysupgrade firmware chính;
- initramfs, kernel1, rootfs0 recovery images;
- build metadata;
- package inventory;
- MTD/partition metadata;
- screenshots;
- UCI export đã redacted;
- restore template đã loại shadow và SSH host private keys.

Muốn tạo full private backup của chính router:

    umask 077
    sysupgrade -b /tmp/openwrt-private-backup.tar.gz
    chmod 600 /tmp/openwrt-private-backup.tar.gz
    sha256sum /tmp/openwrt-private-backup.tar.gz

Sau đó SCP về máy cá nhân và cất offline hoặc encrypted. Không commit file private backup.

Xem docs/BACKUP-RESTORE.md.

## 9. Firmware và recovery

Firmware chính khi router đang chạy OpenWrt và layout vẫn tương thích:

    01_NAP_FILE_NAY_KHI_DANG_O_OPENWRT.bin

SHA-256:

    cdde5ceea7b4c5c044b23b34f1d93c332697fbafc7aac1c7eee8323904b12c21

Không upload file ZIP vào ô flash firmware.

Nếu đã cài Breed, Padavan hoặc firmware khác thì bootloader/partition layout có thể đã thay đổi. Không thử lần lượt kernel1/rootfs0. Xem docs/RECOVERY.md và firmware/README.md.

## 10. App Windows

Source:

    apps/windows/src/khoa_nas_pc.py

Release:

    releases/Khoa-NAS-PC.exe

App hiện:

- kết nối SMB qua Windows WNet API;
- map share thành ổ mạng trong This PC;
- tự chọn drive letter trống từ Z: trở xuống;
- mapping persistent;
- mở app lại tự nhận mapping cũ;
- đóng app không xóa mapping;
- chỉ nút Xóa khỏi This PC mới remove mapping;
- browse, upload, download, create folder, rename, delete;
- timeout/watchdog để không treo vô hạn.

Các lỗi đã sửa:

- busy=True khiến nút Connect xám hàng giờ khi thao tác SMB treo;
- net use với dấu sao tạo password prompt tương tác ngầm;
- Windows Error 86/1326 cho credential sai;
- Error 1219 do session tới cùng server bằng credential khác;
- stale SMB sessions.

### Smart App Control

EXE PyInstaller là unsigned. Windows Smart App Control có thể chặn executable unsigned. Repo không khuyến nghị tắt Smart App Control để né bảo mật.

Có thể:

- chạy source Python;
- hoặc tự code-sign EXE bằng certificate phù hợp.

## 11. App Android

Source Flutter:

    apps/android/

APK:

    releases/Khoa-NAS-Android-v1.0.0.apk

Regression trước khi publish:

- flutter analyze --no-pub: PASS
- flutter test --no-pub: PASS
- flutter build apk --release --no-pub: PASS

Android cần Tailscale hoạt động trên client để truy cập tailnet của router.

## 12. Lệnh vận hành

Status:

    /usr/sbin/nas-storage-manager status

Reconcile:

    /usr/sbin/nas-storage-manager reconcile

Unlock PRIVATE:

    /usr/sbin/nas-storage-manager unlock-private

Lock PRIVATE:

    /usr/sbin/nas-storage-manager lock-private

Safe eject:

    /usr/sbin/nas-storage-manager eject

Xem docs/OPERATIONS.md.

## 13. Các lỗi thực tế đã gặp

docs/TROUBLESHOOTING.md tổng hợp:

- disk không nhận sau reboot;
- mount thấy folder nhưng không mở được;
- NTFS dirty;
- chkdsk /f;
- USB reset, I/O error, device offlined;
- HDD 2.5 inch 7200 RPM và vấn đề nguồn/bridge/cable;
- KSMBD share sai hoặc không reload;
- PRIVATE lock/unlock;
- Tailscale remote SMB;
- credential SMB Windows;
- app PC treo;
- Smart App Control;
- firmware/backup flash nhầm.

## 14. Độ an toàn dữ liệu

Hệ thống từng ghi nhận USB reset và I/O error. Vì vậy:

- SMART PASS không thay thế backup;
- dữ liệu quan trọng phải có bản sao khác;
- NTFS dirty thì ưu tiên Windows chkdsk /f;
- không force RW trên filesystem nghi lỗi;
- nếu USB reset quay lại, kiểm tra nguồn, hub có nguồn, bridge và cable trước khi benchmark nặng.

Historical report và log CHKDSK nằm trong docs/history.

## 15. Security checklist

Xem docs/SECURITY.md.

Tóm tắt:

- WAN 445 không mở;
- remote dùng Tailscale;
- không commit secret;
- auto-unlock PRIVATE có trade-off;
- password SMB nhập và đổi trực tiếp;
- private backup cất offline;
- firmware phải đúng model/layout.

## 16. Bắt đầu từ đâu

- Dựng nhanh: docs/QUICK-START.md
- Restore: docs/BACKUP-RESTORE.md
- Storage/SMB lỗi: docs/TROUBLESHOOTING.md
- PRIVATE VeraCrypt: docs/STORAGE-VERACRYPT.md
- App: docs/APPS.md
- Recovery firmware: docs/RECOVERY.md
- Snapshot hiện tại: docs/CURRENT-STATE.md
- Security: docs/SECURITY.md

## 17. Phạm vi đã verify

Đã verify trên hệ thống thực:

- NAS1/NAS2/PRIVATE mount RW;
- KSMBD running;
- SMB qua Tailscale;
- TCP/445 tailnet;
- create/read/delete SMB nhỏ;
- storage manager self-heal;
- PRIVATE unlock;
- Android analyze/test/build;
- Windows app compile và WNet credential error handling;
- release artifacts được rebuild trước khi publish.

Không tuyên bố:

- raw NAND/OOB clone bit-for-bit;
- recovery bootloader cho mọi trạng thái brick;
- EXE Windows đã code-sign;
- USB/HDD hoàn toàn miễn lỗi phần cứng lâu dài.

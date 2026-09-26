# Backup / Download / Restore

## Public sanitized backup

File:
backups/public/OpenWrt_Backup_Xiaomi_Mi_Router_3G_2026-09-24_SANITIZED.zip

Bản này giữ firmware/recovery và metadata nhưng loại/redact secret.

## Tạo private backup đầy đủ

Trên router:

~~~sh
sysupgrade -b /tmp/openwrt-private-backup.tar.gz
sha256sum /tmp/openwrt-private-backup.tar.gz
~~~

Tải xuống PC:

~~~powershell
scp root@<ROUTER_IP>:/tmp/openwrt-private-backup.tar.gz .
~~~

Hoặc dùng scripts/windows/Create-Private-Backup.ps1.

Private backup có thể chứa:
- /etc/shadow;
- Wi-Fi key;
- SSH host key;
- credential cấu hình.

Không upload lên repo public.

## Restore config archive

~~~sh
sysupgrade -r /tmp/backup.tar.gz
reboot
~~~

Với sanitized backup, sau restore phải cấu hình lại:
- root password;
- Wi-Fi password;
- KSMBD password;
- Tailscale login;
- VeraCrypt passphrase/auto-unlock key.

## Firmware

Trong backup:
- 01_NAP_FILE_NAY_KHI_DANG_O_OPENWRT.bin: image chính khi đang ở OpenWrt.
- initramfs-kernel.bin: recovery nâng cao.
- squashfs-kernel1.bin: recovery nâng cao.
- squashfs-rootfs0.bin: recovery nâng cao.

Không flash file recovery nếu chưa hiểu boot/MTD layout.

## Backup gốc local

SHA-256:
006b2b8a4a36236558a7db954d43c772bebf43e7794bc467a4468d0e6ba0a143

Backup gốc không được upload vì chứa secret.
# Backup và restore

## 1. Hai loại backup

### Public sanitized

Repo chứa:

    backups/public/OpenWrt_Backup_Xiaomi_Mi_Router_3G_2026-09-24_SANITIZED.zip

Gói này giữ firmware, recovery image, metadata và template cấu hình nhưng đã loại hoặc redacted:

- /etc/shadow;
- SSH host private keys;
- Wi-Fi key/password;
- SMB password database;
- Tailscale state/auth key;
- VeraCrypt secret/keyfile.

### Private full backup

Tạo trực tiếp trên router:

    umask 077
    sysupgrade -b /tmp/openwrt-private-backup.tar.gz
    chmod 600 /tmp/openwrt-private-backup.tar.gz
    sha256sum /tmp/openwrt-private-backup.tar.gz

Sau đó SCP về máy cá nhân và cất offline hoặc encrypted.

Không commit private backup lên repo public.

## 2. Tải backup public

Cách clone repo:

    git clone https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt.git

Sau đó mở thư mục:

    backups/public

Hoặc trên GitHub mở file ZIP trong thư mục đó và tải raw/download.

## 3. Restore khi router vẫn chạy OpenWrt

1. Giải nén ZIP.
2. Xác minh model là Xiaomi Mi Router 3G.
3. Vào LuCI -> System -> Backup / Flash Firmware.
4. Chọn file:

       01_NAP_FILE_NAY_KHI_DANG_O_OPENWRT.bin

5. SHA-256 phải là:

       cdde5ceea7b4c5c044b23b34f1d93c332697fbafc7aac1c7eee8323904b12c21

6. Sau khi router boot lại, có thể restore template public sanitized.
7. Đặt lại:
   - root password;
   - Wi-Fi key;
   - SMB password;
   - Tailscale login;
   - VeraCrypt passphrase/auto-unlock policy.

## 4. Nếu đã cài Breed, Padavan hoặc firmware khác

Không flash sysupgrade một cách mù quáng.

Bootloader hoặc partition layout có thể đã thay đổi. Khi đó có thể cần:
- initramfs;
- TFTP;
- UART;
- Breed recovery;
- programmer.

Không thử lần lượt kernel1/rootfs0.

## 5. Backup gốc riêng tư

Backup gốc dùng làm nguồn tạo bản sanitized có SHA-256:

    006b2b8a4a36236558a7db954d43c772bebf43e7794bc467a4468d0e6ba0a143

File gốc cố ý không được commit vì chứa cấu hình nhạy cảm.

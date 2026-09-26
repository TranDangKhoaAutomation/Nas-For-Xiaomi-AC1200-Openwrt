# Firmware / Recovery

Backup public chứa OpenWrt 25.12.5 cho xiaomi_mi-router-3g.

## Image chính

01_NAP_FILE_NAY_KHI_DANG_O_OPENWRT.bin

Chỉ dùng khi đang ở OpenWrt và đã xác minh:

~~~sh
ubus call system board
sha256sum <image>
~~~

## Recovery nâng cao

- initramfs-kernel.bin
- squashfs-kernel1.bin
- squashfs-rootfs0.bin

Các file này không phải lựa chọn mặc định cho LuCI. Chỉ dùng khi hiểu boot/MTD flow của Mi Router 3G.

## Sau flash

1. boot OpenWrt;
2. restore config;
3. reinstall package;
4. copy NAS scripts;
5. set KSMBD password;
6. login Tailscale;
7. kiểm tra mount;
8. unlock PRIVATE;
9. test firewall + SMB.

Không flash image cho model khác.
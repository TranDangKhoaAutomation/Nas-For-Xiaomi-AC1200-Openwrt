# Recovery và firmware

Model đã xác minh:

- Xiaomi Mi Router 3G
- board xiaomi,mi-router-3g
- target ramips/mt7621

Firmware chính khi router đang chạy OpenWrt và partition layout tương thích:

    01_NAP_FILE_NAY_KHI_DANG_O_OPENWRT.bin

SHA-256:

    cdde5ceea7b4c5c044b23b34f1d93c332697fbafc7aac1c7eee8323904b12c21

Nếu router không boot hoặc đã thay bootloader/layout:
- không flash ngẫu nhiên;
- kiểm tra /proc/mtd;
- xác minh bootloader;
- có thể cần initramfs, TFTP, UART, Breed hoặc programmer.

Bộ backup có initramfs-kernel, kernel1 và rootfs0 để recovery tham chiếu.

Bộ này không tuyên bố là raw NAND/OOB clone bit-for-bit.

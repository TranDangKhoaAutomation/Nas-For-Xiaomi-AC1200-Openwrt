# Firmware và recovery inventory

Firmware binaries được đóng trong backup public sanitized để tránh duplicate binary trong Git history.

Firmware chính:

    01_NAP_FILE_NAY_KHI_DANG_O_OPENWRT.bin

SHA-256:

    cdde5ceea7b4c5c044b23b34f1d93c332697fbafc7aac1c7eee8323904b12c21

Recovery images:

- initramfs-kernel:
  09b3f708b81fad4b3a1dd86e252e9beca654d16b16e7aed8d47a46686cbcee90
- squashfs-kernel1:
  fa2d5eb794e25ffff1c7db1388e81107cade0f9c44b8232be615d8a6f8b04298
- squashfs-rootfs0:
  bae4d4f64d992332445d62c8238f7a19af8e7f77045c6bb1e00972889fc1773c

Không flash image recovery theo kiểu thử từng file.

Nếu bootloader hoặc partition layout đã thay đổi do Breed/Padavan/firmware khác, phải xác minh trước.

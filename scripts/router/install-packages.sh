#!/bin/sh
set -eu
apk update
apk add \
  block-mount cryptsetup \
  kmod-fs-ksmbd kmod-fs-ntfs3 \
  kmod-usb-storage kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb3 \
  ksmbd-server ntfs-3g ntfs-3g-utils smartmontools tailscale
echo "Done. Continue with docs/QUICK-START.md"

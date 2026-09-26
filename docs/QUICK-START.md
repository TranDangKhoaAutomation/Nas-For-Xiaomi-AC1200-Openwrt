# Cấu hình nhanh

## 1. Điều kiện

- Router đúng model Xiaomi Mi Router 3G.
- OpenWrt đã boot được.
- HDD/SSD USB ổn định.
- Không format ổ có dữ liệu.
- Client cài Tailscale nếu cần remote access.

## 2. Cài package

OpenWrt 25.12 dùng apk:

    apk update
    apk add block-mount cryptsetup kmod-fs-ksmbd kmod-fs-ntfs3 \
      kmod-usb-storage kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb3 \
      ksmbd-server ntfs-3g ntfs-3g-utils smartmontools tailscale

## 3. Bật Tailscale

    /etc/init.d/tailscale enable
    /etc/init.d/tailscale start
    tailscale up
    tailscale ip -4

Hoàn thành login theo flow của Tailscale. Không lưu auth key trong repo.

## 4. Deploy storage manager

Snapshot đã xác minh nằm trong router/current.

Mapping file:

- usr-sbin-nas-storage-manager -> /usr/sbin/nas-storage-manager
- etc-init.d-nas-storage -> /etc/init.d/nas-storage
- etc-hotplug.d-block-95-nas-storage -> /etc/hotplug.d/block/95-nas-storage

Sau khi copy:

    chmod 755 /usr/sbin/nas-storage-manager
    chmod 755 /etc/init.d/nas-storage
    chmod 755 /etc/hotplug.d/block/95-nas-storage
    /etc/init.d/nas-storage enable
    /etc/init.d/nas-storage restart
    /usr/sbin/nas-storage-manager status

## 5. Cấu hình KSMBD

Snapshot UCI tham chiếu: router/current/etc-config-ksmbd

Tạo user:

    ksmbd.adduser -a nas

Đổi password:

    ksmbd.adduser -u nas
    /etc/init.d/ksmbd restart

Không ghi password trực tiếp vào file script.

## 6. Firewall

Snapshot tham chiếu: router/current/etc-config-firewall

Nguyên tắc:
- tailscale -> TCP 445 -> ACCEPT;
- wan -> TCP 445 -> REJECT.

Không mở SMB trực tiếp ra Internet.

## 7. Kiểm tra

    /usr/sbin/nas-storage-manager status
    mount | grep -E '/mnt/(nas|nas2|private)'
    /etc/init.d/ksmbd status
    tailscale status

Từ Windows:

    \\100.91.1.101\NAS1

PRIVATE chỉ hoạt động khi volume đã unlock.

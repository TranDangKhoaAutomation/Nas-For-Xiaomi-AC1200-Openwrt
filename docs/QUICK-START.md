# Quick Start

## 1. Cài package

~~~sh
apk update
apk add \
  block-mount cryptsetup \
  kmod-fs-ksmbd kmod-fs-ntfs3 \
  kmod-usb-storage kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb3 \
  ksmbd-server ntfs-3g ntfs-3g-utils smartmontools tailscale
~~~

## 2. Copy script

~~~text
scripts/router/nas-storage-manager -> /usr/sbin/nas-storage-manager
scripts/router/nas-storage.init -> /etc/init.d/nas-storage
scripts/router/95-nas-storage -> /etc/hotplug.d/block/95-nas-storage
~~~

~~~sh
chmod 755 /usr/sbin/nas-storage-manager
chmod 755 /etc/init.d/nas-storage
chmod 755 /etc/hotplug.d/block/95-nas-storage
/etc/init.d/nas-storage enable
/etc/init.d/nas-storage start
~~~

## 3. UUID

~~~sh
block info
lsblk -f
~~~

Sửa NAS1_UUID và NAS2_UUID trong manager nếu dùng disk khác.

## 4. KSMBD

~~~sh
ksmbd.adduser -a nas
~~~

Không ghi password vào script.

## 5. Tailscale

~~~sh
/etc/init.d/tailscale enable
/etc/init.d/tailscale start
tailscale up
tailscale ip -4
~~~

## 6. Firewall

Allow TCP/445 từ zone tailscale, reject từ WAN. Không port-forward SMB.

## 7. Kiểm tra

~~~sh
/usr/sbin/nas-storage-manager status
mount | grep '/mnt/'
uci show ksmbd
/etc/init.d/ksmbd status
~~~

Windows:

~~~powershell
Test-NetConnection <TAILSCALE_IP> -Port 445
~~~

Mở:

~~~text
\\<TAILSCALE_IP>\NAS1
~~~
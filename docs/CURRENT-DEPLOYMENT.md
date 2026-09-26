# Current Deployment Snapshot

Snapshot: 2026-09-26.

- OpenWrt 25.12.5 r33051-f5dae5ece4
- Kernel 6.12.94
- Board xiaomi,mi-router-3g
- MediaTek MT7621
- NAS1 mounted RW at /mnt/nas
- NAS2 mounted RW at /mnt/nas2
- PRIVATE mounted RW through /dev/mapper/private at /mnt/private
- KSMBD running
- Tailscale enabled and running
- PRIVATE auto-unlock enabled
- /root/.nas-private-passphrase present with mode 0600
- actual VeraCrypt passphrase is not published
- SMB user: nas

Relevant packages:

~~~text
block-mount
cryptsetup
kmod-fs-ksmbd
kmod-fs-ntfs3
kmod-usb-storage
kmod-usb-xhci-hcd
kmod-usb-xhci-mtk
kmod-usb3
ksmbd-server
ntfs-3g
ntfs-3g-utils
smartmontools
tailscale
~~~

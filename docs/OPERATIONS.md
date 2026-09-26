# Operations

Status:

~~~sh
/usr/sbin/nas-storage-manager status
~~~

Reconcile:

~~~sh
/usr/sbin/nas-storage-manager reconcile
~~~

Unlock/lock PRIVATE:

~~~sh
/usr/sbin/nas-storage-manager unlock-private
/usr/sbin/nas-storage-manager lock-private
~~~

Safe eject:

~~~sh
/usr/sbin/nas-storage-manager eject
~~~

KSMBD:

~~~sh
/etc/init.d/ksmbd status
/etc/init.d/ksmbd restart
uci show ksmbd
~~~

Tailscale:

~~~sh
/etc/init.d/tailscale status
tailscale status
tailscale ip -4
~~~

Disk:

~~~sh
block info
lsblk -f
mount
dmesg | grep -Ei 'usb|sda|I/O|reset|ntfs'
smartctl -a -d sat /dev/sda
~~~
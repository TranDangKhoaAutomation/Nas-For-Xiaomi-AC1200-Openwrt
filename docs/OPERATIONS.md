# Vận hành hàng ngày

Status:

    /usr/sbin/nas-storage-manager status

Reconcile:

    /usr/sbin/nas-storage-manager reconcile

Unlock PRIVATE:

    /usr/sbin/nas-storage-manager unlock-private

Lock PRIVATE:

    /usr/sbin/nas-storage-manager lock-private

Safe eject:

    /usr/sbin/nas-storage-manager eject

KSMBD:

    /etc/init.d/ksmbd status
    /etc/init.d/ksmbd restart

Đổi SMB password:

    ksmbd.adduser -u nas
    /etc/init.d/ksmbd restart

Tailscale:

    tailscale status
    tailscale ip -4

Mount:

    mount | grep -E '/mnt/(nas|nas2|private)'
    block info

Log:

    logread | tail -100
    dmesg | tail -100

Sau khi thay đổi config:
- chạy status;
- kiểm tra UNC;
- tạo file test nhỏ;
- đọc lại;
- xóa file test.

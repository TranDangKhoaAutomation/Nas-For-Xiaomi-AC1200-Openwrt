# Storage và PRIVATE VeraCrypt

## NAS1 / NAS2

Storage manager không phụ thuộc tuyệt đối vào /dev/sdaX. Nó tìm volume theo identity ổ đĩa để giảm lỗi khi Linux đổi thứ tự block device.

Hành vi an toàn:
- không format;
- không tự sửa filesystem;
- không force dirty NTFS RW;
- có thể fallback RO nếu mount RW thất bại;
- disk remove/reset thì cleanup share và mount;
- chỉ bật KSMBD khi có storage thật.

## PRIVATE

Raw partition:

    /dev/sda3

Mapper sau unlock:

    /dev/mapper/private

Mount:

    /mnt/private

Filesystem bên trong là NTFS.

Manual unlock:

    /usr/sbin/nas-storage-manager unlock-private

Lock:

    /usr/sbin/nas-storage-manager lock-private

## Auto-unlock

Snapshot hiện tại có auto-unlock enabled.

Secret nằm ở:

    /root/.nas-private-passphrase

File này không có trong repo.

Ưu điểm:
- reboot xong PRIVATE có thể tự mở.

Nhược điểm:
- quyền root hoặc truy cập router flash có thể làm lộ secret.

Nếu ưu tiên bảo mật vật lý, hãy tắt auto-unlock và nhập passphrase thủ công sau reboot.

## Không commit các file sau

- /root/.nas-private-passphrase
- /etc/ksmbd/ksmbdpwd.db
- Tailscale state
- private sysupgrade backup

# Troubleshooting và lỗi đã gặp

## 1. App PC nút Kết nối xám rất lâu

Nguyên nhân cũ: thao tác SMB blocking làm busy không reset.

Đã sửa:
- TCP 445 preflight;
- timeout path;
- watchdog UI;
- WNet API.

## 2. Nhập đúng password nhưng vẫn báo lỗi

Trên router:

    ksmbd.adduser -u nas
    /etc/init.d/ksmbd restart

Windows:
- Error 86 hoặc 1326: credential bị từ chối.
- Error 1219: đang có session tới cùng server bằng credential khác.

Xóa session cũ tới NAS rồi thử lại.

## 3. Share hiện nhưng mở folder không được

Kiểm tra:

    /usr/sbin/nas-storage-manager status
    mount
    logread | tail -100
    dmesg | tail -100

Nếu NTFS dirty hoặc I/O error, không force ghi.

## 4. Disk không nhận sau reboot

- kiểm tra UUID;
- kiểm tra hotplug;
- kiểm tra nas-storage procd;
- chạy reconcile;
- xem USB reset.

## 5. NTFS dirty

Quy trình đã dùng:
- ntfsfix -n;
- stop SMB;
- sync;
- unmount;
- ntfsfix -d;
- mount lại.

Nếu còn nghi ngờ, gắn vào Windows và chạy:

    chkdsk X: /f

## 6. USB reset / I/O error

Hệ thống từng gặp repeated SuperSpeed reset, I/O error và device offlined.

Ưu tiên kiểm tra:
- nguồn cho HDD 2.5 inch 7200 RPM;
- USB-SATA bridge;
- cable;
- controller;
- hub có nguồn riêng;
- bản thân HDD.

Không benchmark ghi nặng khi đường USB chưa ổn định.

## 7. PRIVATE không xuất hiện

    /usr/sbin/nas-storage-manager status
    /usr/sbin/nas-storage-manager unlock-private

Nếu auto-unlock bật, kiểm tra service và quyền file secret. Không in secret ra log.

## 8. Remote SMB không vào được

- Tailscale client phải cùng tailnet;
- router Tailscale phải running;
- TCP 445 phải accept từ tailscale;
- WAN 445 phải reject.

## 9. EXE Windows bị Smart App Control chặn

EXE PyInstaller chưa code-sign. Dùng source Python hoặc code-sign bản build. Không nên tắt bảo mật chỉ để chạy app.

## 10. Flash firmware nhầm

ZIP backup không phải firmware.

Image initramfs/kernel1/rootfs0 là recovery cấp thấp, không flash thử ngẫu nhiên trong LuCI.

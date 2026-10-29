# Triển khai quản lý ổ đĩa LuCI — 29/10/2026

Thiết bị: Xiaomi Mi Router 3G, OpenWrt 25.12.6, kernel 6.12.112, Tailscale `100.114.53.95`.

## Kết quả

- Thêm **Hệ thống → Ổ đĩa**: quét thiết bị/phân vùng thực tế, thiết lập theo UUID và nhận ổ thay thế; không cố định cho một ổ 100 GiB.
- Quản lý tên, đường dẫn mount, chỉ đọc/đọc ghi, tự gắn/mở khóa; mật khẩu BitLocker nhập trực tiếp trong LuCI và xử lý nền.
- Khóa root-only trong `/etc/nas-disks/keys/`, không xuất ra Git, ảnh hoặc phản hồi RPC.
- Việt/Anh theo LuCI; thêm gói dịch chính thức cho các app đã cài và catalog bổ sung cho Tailscale/nút dịch vụ.
- Sửa Material sidebar có `min-width:max-content`: nhãn tiếng Việt dài xuống dòng, không đè nội dung. Đã kiểm tra trang Khởi động và Ổ đĩa ở cửa sổ hiện tại: menu phải x=208, nội dung trái x=240.
- Dựng/cài `dm-zero` đúng kernel 6.12.112, xác minh digest artifact, APK và vermagic; không force module sai phiên bản.

## Trạng thái storage

| Phân vùng quan sát | Trạng thái |
|---|---|
| Vùng 16 MiB `/dev/sda1` | Chưa có filesystem/UUID được nhận dạng; không cho thao tác mount |
| NTFS `DangKhoa` ~831.5 GiB | Chưa mount; NTFS dirty. Không force hoặc sửa filesystem trong phiên này |
| BitLocker `Data-DangKhoa` ~100 GiB | Đã mở BITLK và mount NTFS3 **ro** tại `/mnt/bitlocker`; share `BITLOCKER` cũng read-only |

Tệp cấu hình hiện hành là `/etc/config/nas_disks`. UUID hiện tại chỉ nằm trong dữ liệu cấu hình; runtime không cố định UUID hoặc tên `sda3`.

## Kiểm tra đã thực hiện

| Kiểm tra | Kết quả |
|---|---|
| Shell, ucode, JavaScript, JSON | PASS cú pháp |
| UUID không tồn tại, đường dẫn ngoài `/mnt`, thiếu mật khẩu | PASS: bị từ chối |
| Yêu cầu RPC chưa đăng nhập | PASS: Access denied |
| Một mật khẩu kiểm tra cố ý sai | PASS: xử lý nền, không lưu khóa, không mount, dọn tệp khóa tạm |
| Mật khẩu thực do người dùng nhập vào LuCI | PASS: mở đúng phân vùng, key 0600, thư mục 0700 |
| Reboot thực tế sau khi tháo mount sạch | PASS: tự nạp dm-zero, tự mở/mount lại, không gọi unlock/mount thủ công |
| Cron, KSMBD, rpcd, uHTTPd sau reboot | Running |
| `fw4 check` sau reboot | PASS |
| Windows qua LAN | `Test-Path \\192.168.1.1\BITLOCKER=True` |
| Windows qua IP tailnet | TCP 445 trên interface Tailscale, `Test-Path \\100.114.53.95\BITLOCKER=True` |
| Ghi SMB trong phiên này | Không thử vì volume chỉ đọc |
| Android thực tế hoặc 4G/5G độc lập | Chưa thử trong phiên này |
| Rút/cắm nóng ổ vật lý mới | Chưa thử trong phiên này; có quét topology, hotplug và đối chiếu UUID |

![Trang ổ đĩa sau reboot, menu không còn che nội dung](screenshots/disks-after-reboot.jpg)

## Mã và hướng dẫn

- [Bộ mã LuCI đang dùng](../../router/luci-disk-manager/README.md)
- [Truy cập NAS từ xa trên Windows và Android](../../docs/REMOTE-ACCESS.md)
- [APK dm-zero đúng kernel và mã băm](../../releases/dm-zero/6.12.112/README.md)
- [Build run 40868849856](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/actions/runs/40868849856)

Backup cấu hình/theme trước thay đổi ở `/root/nas-bitlocker-before-20261029/` trên router. Thư mục này và toàn bộ khóa không được đưa lên repo. Bộ cài lại trong repo được bổ sung sau triển khai; chỉ kiểm tra cú pháp installer, không chạy lại lên router đang hoạt động khi cập nhật Git.

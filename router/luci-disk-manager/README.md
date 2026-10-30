# Quản lý ổ đĩa trong LuCI

Mã đang triển khai trên OpenWrt 25.12.6, cập nhật ngày 30/10/2026. Trang ở **Hệ thống → Ổ đĩa** (`/cgi-bin/luci/admin/system/disks`), nhận danh sách ổ/phân vùng thực tế và lưu thiết lập theo UUID.

**Các dịch vụ → Hướng dẫn kết nối** (`/cgi-bin/luci/admin/services/nas-connect`) hướng dẫn mở NAS trên Windows/Android ngay trong router. Chọn truy cập từ xa qua Tailscale hoặc mạng nhà, rồi chọn thư mục chia sẻ. IP, tài khoản SMB được cấu hình, trạng thái gắn/chỉ đọc và đường dẫn sao chép lấy từ router hiện tại; không cố định theo ổ hoặc IP tham chiếu. Có liên kết tới trang này ngay trong trang Ổ đĩa.

## Chức năng

- Xem dung lượng, filesystem, trạng thái gắn/mở khóa, dung lượng trống và share SMB hiện có.
- Thiết lập tên hiển thị, đường dẫn dưới `/mnt`, chỉ đọc/đọc ghi, tự gắn/mở khóa cho từng UUID.
- Nhập mật khẩu BitLocker trực tiếp trong LuCI; xử lý nền, không truyền qua argv hoặc URL.
- Chỉ lưu mật khẩu đã xác minh khi bật tự mở; khóa root-only trong `/etc/nas-disks/keys/` (thư mục 0700, tệp 0600).
- Gắn/tháo an toàn; không force dirty NTFS, không format hoặc sửa filesystem tự động.
- Nhận thay đổi thiết bị và disk sequence; có nút quét lại. Ổ khác UUID không nhận nhầm khóa/cấu hình của ổ cũ.
- Tiếng Việt/Anh theo ngôn ngữ LuCI; bổ sung bản dịch Tailscale và các nút dịch vụ.
- Sửa chung theme Material để nhãn menu dài xuống dòng, không che nội dung.

Các filesystem có thể gắn còn phụ thuộc driver đã cài trên router. `dm-zero` phải khớp kernel để dùng BitLocker; xem [gói cho 6.12.112](../../releases/dm-zero/6.12.112/README.md).

## Cài mới hoặc cài lại

Thiết bị cần có LuCI, `rpcd-mod-ucode`, `block-mount`, `cryptsetup`, `kmod-dm`, driver filesystem tương ứng và KSMBD nếu dùng SMB. Script dành cho OpenWrt 25.12 dùng ucode; không restore nguyên cấu hình router cũ.

1. Chép **cả thư mục này** sang router qua SSH/SCP. Không chép các khóa, mật khẩu hoặc backup riêng tư vào repo.
2. Nếu nâng từ manager BitLocker cũ, tháo volume cũ an toàn trước khi chuyển. Installer tắt hook/service cũ, không tự đóng volume đang sử dụng và không tự chuyển khóa cũ.
3. Trên router, đứng trong thư mục đã chép và chạy:

   ```sh
   sh install.sh
   ```

4. Đăng xuất/đăng nhập lại LuCI để phiên mới nhận ACL của trang. Mở **Hệ thống → Ổ đĩa → Quản lý** trên phân vùng mong muốn.
5. Chọn đường dẫn, chế độ truy cập và tự gắn/mở khóa; với BitLocker, nhập mật khẩu rồi bấm **Lưu và mở khóa**.

Installer không chứa UUID, IP, đường dẫn mount riêng của ổ tham chiếu hoặc mật khẩu. Cấu hình hiện có trong `/etc/config/nas_disks` được giữ; bản sao cấu hình trước thay đổi nằm trong `/root/nas-disks-install-<thời gian>/`.

Tắt tự mở không xóa khóa đã lưu. Người có root hoặc đọc được flash/backup chứa khóa có thể lấy mật khẩu. Giữ recovery key riêng. Sau nâng firmware/kernel, phải kiểm tra lại module và các tệp tùy chỉnh.

## Mã và bản dịch

| Tệp | Nơi dùng trên router |
|---|---|
| `disks.uc` | `/usr/share/rpcd/ucode/disks.uc`, object `nas.disks` |
| `acl.json`, `menu.json` | RPC ACL và menu LuCI |
| `nas-disks.js`, `nas-connect.js` | View quản lý ổ và hướng dẫn kết nối trong LuCI |
| `nas-disks-manager` | Mount/unmount theo UUID, reconcile |
| `nas-disks-job` | Xử lý mật khẩu và thao tác nền |
| `nas-disks-scan` | Quét sysfs, block metadata và trạng thái mount |
| `nas-disks.init`, `96-nas-disks` | Boot S96 và hotplug |
| `vi.json`, `tailscale.vi.json` | Nguồn dịch |
| `compile_catalog.py` | Tạo catalog LMO Việt/Anh gốc của LuCI |
| `material-layout-fix.css`, `patch-material.uc` | Sửa menu Material và nạp tài nguyên mới |

Tạo lại catalog trên máy phát triển:

```powershell
python router/luci-disk-manager/compile_catalog.py
```

Runtime đã được kiểm tra trực tiếp: cú pháp, API/ACL, xử lý mật khẩu sai, mở khóa thực, root-only key, reboot tự mở và SMB chỉ đọc. Installer là công cụ cài lại được bổ sung vào repo, được kiểm tra cú pháp; không chạy lại installer trên router đang hoạt động trong lần cập nhật Git này.

Ngày 30/10 đã kiểm tra trang Hướng dẫn kết nối bằng Chrome qua IP Tailscale: menu, bản dịch tiếng Việt, Windows/Android, chọn LAN/Tailscale, chọn share chưa gắn/chỉ đọc, làm mới và nút sao chép. API `connection_info` chỉ đọc thông tin kết nối; không đọc hoặc trả về mật khẩu/khóa. Trạng thái gắn nhận diện các mount dữ liệu dưới `/mnt`, không chứng minh quyền tailnet hay kết nối SMB của máy khách. Chưa thử kết nối thực tế từ Android/4G.

Hướng dẫn sử dụng: [truy cập từ xa bằng Windows/Android](../../docs/REMOTE-ACCESS.md). Kết quả triển khai: [báo cáo 29/10](../../reports/2026-10-29-disk-manager/README.md).

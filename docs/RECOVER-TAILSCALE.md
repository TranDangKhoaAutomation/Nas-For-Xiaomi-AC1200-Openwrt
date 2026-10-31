# Khôi phục kết nối Tailscale trên router

**Dùng khi có LAN hoặc console của đúng router. Không chạy qua phiên SSH Tailscale đang cần sửa.**

## Sự cố hiện tại — 31/10/2026

Router vẫn trả lời TSMP và PeerAPI, nhưng SSH, LuCI và SMB chưa truy cập được. Đã thử cấp IP tạm `100.114.53.96` trong trang quản trị rồi trả lại **`100.114.53.95`**; SSH/HTTP vẫn timeout sau khi trả IP. Chưa khôi phục router. [Kết quả kiểm tra](../reports/2026-10-31-router-recovery/README.md).

Tailscale online hoặc ping TSMP thành công chỉ xác nhận một phần đường kết nối. Theo [tài liệu ping của Tailscale](https://tailscale.com/docs/reference/ping-types), TSMP đi qua đường mã hóa nhưng không kiểm tra ngăn xếp IP của hệ điều hành; PeerAPI cũng không chứng minh SSH/SMB hoạt động.

## Khi có đường LAN

1. Kết nối máy tính vào LAN/Wi-Fi của đúng router OpenWrt. Dùng khóa SSH đã lưu và kiểm tra host key; nếu báo thay đổi khóa, dừng để xác minh thiết bị. Không chấp nhận khóa mới chỉ vì cùng địa chỉ `192.168.1.1`.
2. Chuyển [repair-tailscale.sh](../router/helpers/router/repair-tailscale.sh) vào `/tmp/repair-tailscale.sh` trên router. Với Dropbear không có SFTP, có thể dùng `scp -O`. Đọc trạng thái trước:

   ```sh
   sh /tmp/repair-tailscale.sh --check
   ```

3. Trong phiên **SSH qua LAN hoặc console**, khởi động lại riêng dịch vụ Tailscale:

   ```sh
   sh /tmp/repair-tailscale.sh --restart
   ```

   Công cụ dừng dịch vụ, chờ tiến trình `tailscaled` cũ thoát rồi mới gọi start. Nếu tiến trình không dừng trong 10 giây hoặc bước stop lỗi, công cụ dừng tại đó. Công cụ không dùng kill cưỡng bức, không sửa firewall, không thay tài khoản, không cài gói, không xóa đăng nhập Tailscale và không thao tác ổ đĩa/BitLocker. Mặc định không có tham số chỉ kiểm tra. Phiên SSH có nguồn hoặc đích thuộc Tailscale/CGNAT bị chặn trước thao tác dịch vụ.
4. Từ **một thiết bị Tailscale khác**, kiểm tra lại SSH tới `100.114.53.95`, mở [LuCI](http://100.114.53.95/cgi-bin/luci/) và thử SMB. Công cụ thấy lại địa chỉ trên `tailscale0` chưa đủ để kết luận dịch vụ đã khôi phục.

Nếu vẫn lỗi, giữ phiên LAN để kiểm tra `ip addr show dev tailscale0`, `ip route show table 52`, `fw4 check` và `logread -e tailscale`. Nhật ký có thể chứa thông tin thiết bị/mạng; không đăng toàn bộ công khai. Không chạy lại installer, reset router, format ổ hoặc đổi mật khẩu để xử lý timeout mạng.

## Vì sao tránh gọi start trên dịch vụ đang chạy?

[Init script OpenWrt 25.12](https://raw.githubusercontent.com/openwrt/packages/openwrt-25.12/net/tailscale/files/tailscale.init) gọi `tailscaled --cleanup` trong start. [Mã nguồn Tailscale 1.104.1](https://raw.githubusercontent.com/tailscale/tailscale/v1.104.1/wgengine/router/osrouter/router_linux.go) cho thấy cleanup còn gỡ địa chỉ Tailscale trên giao diện. Một daemon vẫn sống có thể tiếp tục trả lời qua kênh riêng trong khi đường IP của hệ điều hành bị ảnh hưởng. Đây là cơ chế phù hợp với quan sát; chưa có nhật ký trong router để khẳng định đầy đủ nguyên nhân.

Installer trong mã nguồn hiện tại đã chặn start khi `tailscaled` còn chạy. Công cụ khôi phục này là công cụ riêng trong repo, **chưa chạy trên router đang lỗi và chưa nằm trong gói release `khoanas-2026.10.31.1`**. Không bật tự khôi phục hay tự khởi động lại theo lịch.

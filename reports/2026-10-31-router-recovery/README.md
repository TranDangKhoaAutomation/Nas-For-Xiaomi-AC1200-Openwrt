# Kiểm tra và thử khôi phục router — 31/10/2026

**Kết quả lúc khoảng 10:08 GMT+7: chưa khôi phục quản trị/NAS.** Router đã được trả lại địa chỉ Tailscale **100.114.53.95**, vẫn online và trả lời TSMP/PeerAPI. Không chạy được lệnh trong router qua SSH. Mất truy cập ban đầu xảy ra trong lần kiểm thử installer ngày 30/10; không coi bản sửa app hay trạng thái online là đã khắc phục sự cố này.

## Các bước đã thực hiện

| Kiểm tra/thao tác | Quan sát |
|---|---|
| Tailscale Windows | Backend Running, không có cảnh báo health trong status đã đọc |
| Router trên Tailscale | Online, phiên bản 1.104.1-1 OpenWrt, không có subnet route hoặc SSH host key trong status |
| TSMP | Trả lời; lần cuối khoảng 49 ms |
| PeerAPI | Trả HTTP thành công; lần cuối khoảng 104 ms. Đây là kênh của daemon, không phải LuCI |
| Quản trị Tailscale trước thử IP | Thiết bị Connected; khóa chưa hết hạn; chính sách cho mọi thiết bị tới mọi cổng/giao thức; không có máy khác đang online để làm cầu nối LAN |
| Chẩn đoán PeerAPI `/v0/interfaces` | HTTP 403 do chưa có debug access; không vượt qua giới hạn này |
| Các cổng IPv4 trước thử | 22/80/445/443 timeout; ICMP không trả lời |
| IPv6 trước thử | 22/80/445/443 connection refused; chưa có đường quản trị thay thế |
| Địa chỉ router từng công bố trong LAN | SSH tới 192.168.0.103, 192.168.1.1 và 192.168.1.3 timeout trong lượt này; chỉ dùng khóa host đã ghim, không chấp nhận thiết bị/khóa khác |
| IP tạm 100.114.53.96 | Trang quản trị và status nhận địa chỉ mới; PeerAPI thành công; SSH/HTTP/ICMP vẫn không được; web quản trị Tailscale cổng 5252 timeout |
| Trả về 100.114.53.95 | Status nhận lại IP cũ; TSMP/PeerAPI thành công; SSH và HTTP tiếp tục timeout |

Không thay chính sách truy cập, xóa/expire thiết bị, thay mật khẩu, reset router hoặc can thiệp ổ đĩa. Thay đổi IP là thử nghiệm có hoàn nguyên, không khôi phục được các dịch vụ.

## Nhận định và giới hạn

[Tài liệu ping](https://tailscale.com/docs/reference/ping-types) phân biệt đường TSMP/daemon và đường IP của hệ điều hành. Triệu chứng cho thấy daemon còn liên lạc được nhưng đường tới dịch vụ hệ điều hành chưa sử dụng được.

[Init script OpenWrt 25.12](https://raw.githubusercontent.com/openwrt/packages/openwrt-25.12/net/tailscale/files/tailscale.init) gọi cleanup trong start; [Tailscale 1.104.1](https://raw.githubusercontent.com/tailscale/tailscale/v1.104.1/wgengine/router/osrouter/router_linux.go) gỡ địa chỉ Tailscale khi cleanup. Cơ chế này phù hợp với thời điểm mất kết nối trong lần installer trước. Chưa đọc được địa chỉ, route, firewall và nhật ký trực tiếp trong router sau sự cố nên chưa thể khẳng định nguyên nhân đầy đủ. Thử cấp lại IP không đủ khôi phục.

Không có shell từ xa, web quản trị hoạt động, subnet gateway hoặc máy tại LAN để áp bản sửa lên router. Người dùng xác nhận router ở xa, chưa có người hỗ trợ. Không có phép thử SMB thật sau sự cố; trạng thái ổ và quyền đọc/ghi hiện tại chưa xác minh lại.

## Công cụ khôi phục đã chuẩn bị

[Hướng dẫn](../../docs/RECOVER-TAILSCALE.md) và [repair-tailscale.sh](../../router/helpers/router/repair-tailscale.sh) dành cho khi có LAN/console. Mặc định chỉ kiểm tra; `--restart` dừng dịch vụ và chờ daemon cũ thoát rồi mới start, giữ đăng nhập và cấu hình hiện có. Không chạy qua Tailscale.

Kiểm thử mô phỏng trên máy phát triển: **6 bài đạt**, gồm từ chối SSH Tailscale trước mọi thao tác, cho phép LAN/console, thứ tự stop–chờ–start, không start nếu stop lỗi hoặc tiến trình cũ còn sống, và trả lỗi nếu start thất bại. Kiểm tra cú pháp shell đạt. Đây không phải kiểm thử thành công trên OpenWrt thật; công cụ chưa được tải lên hoặc chạy trên router đang lỗi.

Gói APK/EXE và release `khoanas-2026.10.31.1` giữ nguyên. Bản cập nhật repo này bổ sung công cụ/hướng dẫn và kết quả chẩn đoán, không đánh dấu sự cố router đã xong.

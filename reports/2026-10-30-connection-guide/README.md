# Hướng dẫn kết nối trong giao diện router — 30/10/2026

Đã triển khai **Các dịch vụ → Hướng dẫn kết nối** tại `/cgi-bin/luci/admin/services/nas-connect`, kèm liên kết từ trang **Hệ thống → Ổ đĩa**.

![Trang hướng dẫn kết nối trên router](screenshots/connection-guide.jpg)

Trang có hướng dẫn Windows (mở File Explorer, map ổ vào This PC) và Android (thêm SMB2/SMB3), chọn LAN hoặc Tailscale, chọn share, sao chép thông tin và làm mới. IP và danh sách share/tài khoản lấy từ cấu hình router; trạng thái mount đọc từ hệ thống, chỉ trả về thông tin kết nối, không mật khẩu hay khóa.

Đã kiểm tra trực tiếp qua Chrome tại IP Tailscale của router:

- Menu và nội dung tiếng Việt; nguồn dịch Việt/Anh được biên dịch lại.
- Chọn LAN/Tailscale cập nhật địa chỉ và đường dẫn Windows đúng.
- Chọn `BITLOCKER` hiện chỉ đọc; chọn `DANGKHOA` cảnh báo chưa gắn.
- Tab Android hiện host, cổng 445, share và tài khoản hiện tại.
- Nút làm mới và sao chép đường dẫn hoạt động.
- API chưa đăng nhập trả về Access denied; phản hồi đã đăng nhập chỉ chứa các trường metadata dự kiến.
- 7 tệp RPC/ACL/menu/view/catalog trên router khớp SHA-256 với nguồn triển khai. BitLocker vẫn gắn chỉ đọc.
- JavaScript, JSON, ucode và shell installer qua kiểm tra cú pháp. Bộ vá Material chạy trên bản sao header, giữ nội dung và chạy lặp lại cho cùng kết quả; installer đầy đủ chưa chạy lại trên router đang dùng.

Trạng thái mount trên trang chỉ nhận diện mount dữ liệu dưới `/mnt`; chưa kiểm tra kết nối Android hoặc 4G/5G thực tế. Không reboot, đổi firewall hay thao tác gắn/tháo ổ trong cập nhật giao diện này.

Mã: [luci-disk-manager](../../router/luci-disk-manager/README.md). Hướng dẫn đầy đủ: [truy cập từ xa](../../docs/REMOTE-ACCESS.md).

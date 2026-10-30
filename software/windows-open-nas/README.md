# Mở thư mục NAS từ giao diện router

Nút **Mở thư mục NAS** trong **Các dịch vụ → Hướng dẫn kết nối** gửi IP và tên share đang chọn cho tiện ích Windows qua liên kết `khoanas://`. Tiện ích mở File Explorer bằng phiên SMB hiện có; Windows tự hỏi đăng nhập SMB nếu cần.

## Cài một lần trên mỗi máy Windows

1. Tải [KhoaNAS-Open.exe](../../releases/windows-open-nas/KhoaNAS-Open.exe).
2. Chạy tệp và nhập IP router được phép, cách nhau bằng dấu phẩy. Lấy IP từ trang Hướng dẫn kết nối; có thể nhập cả IP LAN và Tailscale. Bộ cài không cần quyền quản trị.
3. Trở lại router, chọn kiểu kết nối và share rồi bấm **Mở thư mục NAS**. Nếu Chrome hỏi mở ứng dụng, chọn mở khi đích đúng router của bạn.

Tiện ích được cài dưới `%LOCALAPPDATA%\KhoaNAS-Open`, đăng ký giao thức cho tài khoản Windows hiện tại tại `HKCU\Software\Classes\khoanas`. Khi đổi IP router, chạy lại bộ cài và nhập danh sách IP mới. Tiện ích không bật VPN, không map ổ, không lưu mật khẩu và không đổi quyền đọc/ghi.

Bản EXE chưa ký số. Nếu Windows chặn chạy theo chính sách máy, cần bản được ký/được quản trị viên cho phép; không tắt bảo vệ hệ thống để chạy. Máy Windows tham chiếu đã cài bản nguồn bằng Python có sẵn; tải EXE dành cho các máy khác không có Python.

Trên Android, nút dùng `smb://<IP>/<share>` và cần ứng dụng quản lý tệp nhận loại liên kết đó. Nếu không có ứng dụng phù hợp, dùng hướng dẫn nhập kết nối SMB bên dưới nút. Nút không tự cấp quyền hay thay thế kết nối Tailscale khi truy cập từ xa.

## Phạm vi và kiểm tra

Tiện ích chỉ chấp nhận IPv4 riêng RFC1918 hoặc Tailscale `100.64.0.0/10`, và chỉ mở IP đã được cho phép lúc cài. Đích là gốc một share; không nhận đường dẫn tệp, lệnh shell, mật khẩu hoặc máy chủ Internet công cộng. Không có UUID/share/IP riêng được cố định trong mã.

```powershell
python -m unittest discover -s software/windows-open-nas -v
python software/windows-open-nas/open_nas.py --install --allow-host <IP-router>
```

Build bằng Python 3.12 và PyInstaller 6.22.2:

```powershell
pyinstaller --noconfirm --onefile --windowed --name KhoaNAS-Open software/windows-open-nas/open_nas.py
```

Kiểm tra tự động gồm liên kết hợp lệ, share có dấu cách, chặn host công cộng/DNS, đường dẫn con, ký tự điều khiển, tham số lặp/thừa và chèn lệnh. Không tự động thao tác ghi lên NAS khi kiểm tra nút mở thư mục.

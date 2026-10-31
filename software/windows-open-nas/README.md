# Mở thư mục NAS từ giao diện router

Nút **Mở thư mục NAS** trong **Các dịch vụ → NAS → Hướng dẫn kết nối** gửi IP và tên share đang chọn cho tiện ích Windows qua liên kết `khoanas://`. Tiện ích mở File Explorer bằng phiên SMB hiện có; Windows tự hỏi đăng nhập SMB nếu cần.

Giao diện **Qt 6 / PySide6**, bản Windows **1.1.0**: logo, ô IP, tùy chọn **Khởi động cùng Windows** và nút **Lưu thiết lập**. Hướng dẫn nằm trong Trợ giúp. Logo lấy từ ảnh đại diện GitHub của chủ repo và đóng gói sẵn.

Cửa sổ rộng 500 px và tự tính chiều cao theo nội dung; bỏ khoảng trống kéo giãn giữa ô IP và hàng nút. Thông báo xuất hiện sẽ tự điều chỉnh kích thước cửa sổ.

## Cài một lần trên mỗi máy Windows

1. Tải [KhoaNAS-Open.exe mới nhất](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Open.exe).
2. Chạy tệp và nhập IP router được phép, cách nhau bằng dấu phẩy. Lấy IP từ trang Hướng dẫn kết nối; có thể nhập cả IP LAN và Tailscale. Bộ cài không cần quyền quản trị.
3. Tích **Khởi động cùng Windows** nếu muốn và bấm **Lưu thiết lập**. Mặc định tắt; cập nhật giữ lựa chọn cũ.
4. Trở lại router, chọn kiểu kết nối và share rồi bấm **Mở thư mục NAS**. Nếu Chrome hỏi mở ứng dụng, chọn mở khi đích đúng router của bạn.

Tiện ích luôn được cài dưới `%LOCALAPPDATA%\KhoaNAS-Open`. Start Menu chỉ có một mục **Khoa NAS** trỏ tới bản cài cố định; tệp tải về chuyển sang bản cài này khi mở. Khi đổi IP hoặc tùy chọn, mở **Khoa NAS** từ Start Menu. Giao thức đăng ký cho tài khoản hiện tại tại `HKCU\Software\Classes\khoanas`.

## Khởi động cùng Windows

Bật tùy chọn rồi lưu để đăng ký đúng một giá trị `KhoaNAS-Open` tại `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, trỏ tới bản đã cài với `--background`. Chỉ áp dụng cho tài khoản hiện tại, không cần quyền quản trị. Bỏ tích và lưu sẽ xóa giá trị của app; không thay đổi chương trình khởi động khác.

Khi đăng nhập, app chạy nền ở khay hệ thống, không bật cửa sổ, không tự mở NAS hay map ổ. Nhấp đôi biểu tượng hoặc chọn **Cài đặt…** để mở lại. Menu có **Mở NAS** theo IP đã cho phép và **Thoát** cho phiên Windows hiện tại. Thoát không tắt tùy chọn của lần đăng nhập sau. Khi tắt tùy chọn, đóng cài đặt sẽ thoát app. Mở nhiều lần chỉ kích hoạt cùng một cửa sổ/biểu tượng.

Lịch khởi động do Windows điều phối, có thể chạy trễ sau đăng nhập. Nếu bạn tắt app trong danh sách Startup của Windows, cần bật lại tại đó. Không tự đăng nhập Tailscale hoặc lưu mật khẩu SMB. Nút mở thư mục vẫn dùng được khi tùy chọn chạy nền tắt.

Nếu tìm kiếm Windows hiện nhiều EXE giống tên, đó có thể là các bản tải/build nằm trong Documents hoặc Downloads. Giữ một bản cài và shortcut **Khoa NAS**; có thể lưu bản build cũ ngoài thư mục được Search lập chỉ mục. Không cần chạy từng EXE hoặc cài từng bản. Danh sách tìm kiếm cập nhật theo lịch lập chỉ mục của Windows.

Bản EXE chưa ký số. Nếu Windows chặn chạy theo chính sách máy, cần bản được ký/được quản trị viên cho phép; không tắt bảo vệ hệ thống để chạy. Máy Windows tham chiếu đã cài bản nguồn bằng Python có sẵn; tải EXE dành cho các máy khác không có Python.

Trên Android, nút dùng `smb://<IP>/<share>` với app Khoa NAS hoặc ứng dụng nhận loại liên kết đó. Nút không tự cấp quyền hay thay thế đăng nhập Tailscale.

## Phạm vi và kiểm tra

Tiện ích chỉ chấp nhận IPv4 riêng RFC1918 hoặc Tailscale `100.64.0.0/10`, và chỉ mở IP đã được cho phép lúc cài. Đích là gốc một share; không nhận đường dẫn tệp, lệnh shell, mật khẩu hoặc máy chủ Internet công cộng. Không có UUID/share/IP riêng được cố định trong mã.

```powershell
python -m unittest discover -s software/windows-open-nas -v
python software/windows-open-nas/open_nas.py --install --allow-host <IP-router>
```

Build bằng Python 3.12, PySide6 6.11.2 và PyInstaller 6.22.2. Đứng tại thư mục repo:

```powershell
python -m pip install -r software/windows-open-nas/requirements.txt
python software/windows-open-nas/build.py --output dist/nas-open --work build/nas-open
```

Kiểm tra tự động gồm liên kết hợp lệ, giới hạn host/đường dẫn, bật/tắt Run chỉ sửa giá trị của app, giữ IP khi cập nhật, quoting đường dẫn có khoảng trắng, lưu checkbox, khóa một phiên và IPC giữa tiến trình thật. IPC chỉ cho mở cài đặt/liên kết NAS đã kiểm tra, không nhận đường dẫn chương trình hoặc lệnh shell. Không ghi lên dữ liệu NAS trong kiểm thử.

[Báo cáo cập nhật và ảnh cài đặt 31/10](../../reports/2026-10-31-windows-startup/README.md).

Xem [thông tin thư viện và logo](assets/THIRD-PARTY-NOTICES.md). Không kèm trạng thái Tailscale, mật khẩu hoặc IP cá nhân được cố định trong EXE.

Script build loại bản ICU bên thứ ba trùng tên mà PATH máy phát triển có thể đưa nhầm vào gói. Qt dùng `icuuc.dll` của Windows; không thay DLL hệ thống. Bản EXE được kiểm tra khởi chạy trên Windows 11 x64 trước khi phát hành.

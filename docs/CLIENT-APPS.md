# Ứng dụng máy khách

**Để truy cập NAS từ xa hiện tại, dùng [hướng dẫn Windows và Android](REMOTE-ACCESS.md).** Windows dùng File Explorer/map ổ; Android dùng SMB client cho nhập tên share BITLOCKER.

Các app bên dưới là bản cũ của NAS1/NAS2/PRIVATE. Bản Android hiện có IP mặc định `100.91.1.101` và danh sách share cố định; chưa cập nhật cho cấu hình mới. Các kết quả build/test bên dưới là lịch sử, không phải kiểm tra lại app ngày 29/10/2026.


## Windows — Khoa-NAS-PC

Source:
software/pc/khoa_nas_pc.py

Tính năng:
- SMB login;
- map persistent Network Drive;
- tự nhận mapping;
- Ngắt trong app không xóa ổ khỏi This PC;
- Xóa khỏi This PC mới unmap;
- upload/download;
- create/rename/delete;
- timeout/watchdog;
- WNet API.

Chạy source:

~~~powershell
pythonw software\pc\khoa_nas_pc.py
~~~

Build:

~~~powershell
pip install pyinstaller
pyinstaller --noconfirm --clean --onefile --windowed --name Khoa-NAS-PC software\pc\khoa_nas_pc.py
~~~

EXE unsigned có thể bị Smart App Control chặn.

## Android Flutter

Source:
software/android/

Dependencies chính:
- dart_smb2
- flutter_secure_storage
- file_picker
- path_provider

Build:

~~~sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
~~~

Regression hiện tại:
- analyze: PASS
- tests: PASS

Android remote SMB cần Tailscale đang kết nối.
# App Windows và Android

## Windows

Source:

    apps/windows/src/khoa_nas_pc.py

Release:

    releases/Khoa-NAS-PC.exe

App Windows dùng WNet API thay cho net use password prompt.

Chức năng:
- map share thành ổ mạng trong This PC;
- persistent mapping;
- tự nhận mapping khi mở lại;
- upload/download;
- create folder;
- rename;
- delete;
- hiển thị dung lượng;
- timeout/watchdog.

Lỗi đã sửa:
- UI kẹt busy;
- prompt net use dấu sao;
- Error 86/1326;
- Error 1219;
- stale session.

EXE hiện unsigned nên Smart App Control có thể block. Không cần tắt Smart App Control; có thể chạy source Python hoặc code-sign build riêng.

## Android

Source:

    apps/android

APK:

    releases/Khoa-NAS-Android-v1.0.0.apk

Flutter client dùng SMB2/3.

Regression:
- flutter analyze: PASS;
- flutter test: PASS;
- release APK build: PASS.

Android cần Tailscale chạy nếu dùng tailnet IP.

# Khoa NAS - Windows

Source hiện tại:

    src/khoa_nas_pc.py

Release:

    ../../releases/Khoa-NAS-PC.exe

App dùng Windows WNet API để map SMB share vào This PC.

Chức năng:
- host mặc định 100.91.1.101;
- share NAS1, NAS2, PRIVATE;
- map persistent thành ổ mạng;
- tự nhận mapping cũ;
- chỉ gỡ khỏi This PC khi người dùng bấm Xóa khỏi This PC;
- upload/download/create/rename/delete;
- timeout và watchdog chống treo UI;
- nhận mã lỗi Windows rõ ràng cho credential/session conflict.

EXE hiện unsigned. Smart App Control có thể chặn. Khi đó chạy source Python hoặc tự code-sign bản build.

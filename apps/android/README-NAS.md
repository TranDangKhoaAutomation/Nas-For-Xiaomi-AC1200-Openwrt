# Khoa NAS - Android

Flutter client truy cập SMB2/3 qua Tailscale.

Release APK:

    ../../releases/Khoa-NAS-Android-v1.0.0.apk

Trước khi đưa vào repo đã chạy:

- flutter analyze --no-pub: PASS
- flutter test --no-pub: PASS
- flutter build apk --release --no-pub: PASS

Điện thoại cần bật Tailscale và đăng nhập đúng tailnet nếu dùng IP 100.91.1.101.

PRIVATE chỉ truy cập được khi volume đã unlock.

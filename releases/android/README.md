# Khoa NAS 2.0.0 — Android

App Material 3 có Tailscale tích hợp, duyệt/tải tệp SMB và quản lý phân vùng router.
Android tối thiểu 8.0/API 26. Chọn **arm64-v8a** cho điện thoại phổ biến;
**x86_64** dành cho LDPlayer và máy ảo tương ứng. Không cần cài app Tailscale riêng.

Đây là bản thử nghiệm ký bằng khóa Android debug cục bộ. Mã nguồn/build ở
[software/android](../../software/android/README.md), kết quả kiểm thử ở
[báo cáo LDPlayer](../../reports/2026-10-30-android-integrated/README.md).
Đã kiểm thử SMB nội bộ trên máy ảo; đăng nhập tailnet thật và thử 4G/5G còn chờ chủ tài khoản.

| APK | Bytes | SHA-256 |
|---|---:|---|
| [KhoaNAS-v2.0.0-arm64-v8a.apk](KhoaNAS-v2.0.0-arm64-v8a.apk) | 40427235 | `7b651f800d882f6261c4f82ba51ca38892b83d6c3cca7250df3be1a58ae8ddf7` |
| [KhoaNAS-v2.0.0-x86_64.apk](KhoaNAS-v2.0.0-x86_64.apk) | 43551799 | `7d15d15fd9149c7021c97d8735ed02b6f3b93dcbcfaed6ff0d89a17fa1c34dcb` |

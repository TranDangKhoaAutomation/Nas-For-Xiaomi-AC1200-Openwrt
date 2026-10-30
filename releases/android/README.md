# Khoa NAS 2.3.0 — Android

App Material 3 có Tailscale tích hợp, chọn router từ danh sách tailnet, lưới/danh sách, ảnh/video trực tiếp, thumbnail/thời lượng, cắt/xoay ảnh lưu bản sao và sao lưu nền có thiết lập.
Android tối thiểu 8.0/API 26. Chọn **arm64-v8a** cho điện thoại phổ biến;
**x86_64** dành cho LDPlayer và máy ảo tương ứng. Không cần cài app Tailscale riêng.

Đây là bản thử nghiệm ký bằng khóa Android debug cục bộ. Mã nguồn/build ở
[software/android](../../software/android/README.md), kết quả kiểm thử ở
[báo cáo 2.3](../../reports/2026-10-30-android-2.3/README.md).
Đã kiểm thử SMB nội bộ bản 2.0 trên máy ảo; sao lưu nền/codec/streaming NAS thật bản 2.3 và 4G còn cần xác minh. Chủ máy chọn cài 2.3 sau; bản này chưa cài lên Samsung. Sao lưu mặc định tắt. [Hướng dẫn cài](../../docs/INSTALL.md) · [Hướng dẫn ảnh và sao lưu](../../docs/ANDROID-BACKUP.md).

| APK | Bytes | SHA-256 |
|---|---:|---|
| [KhoaNAS-v2.3.0-arm64-v8a.apk](KhoaNAS-v2.3.0-arm64-v8a.apk) | 42938042 | `7813fd89bd076ff40d0f5262c759d77e959dc4c97713efe127da1572c4c8b8d1` |
| [KhoaNAS-v2.3.0-x86_64.apk](KhoaNAS-v2.3.0-x86_64.apk) | 46065650 | `7fef47e27b950577b1a18146ff78066ebb8a565861e05406b6701f9eec3dc24a` |

APK 2.0 được giữ cho các báo cáo lịch sử. [Tải bản ARM64 mới nhất](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Android.apk).

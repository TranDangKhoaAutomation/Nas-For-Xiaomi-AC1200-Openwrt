# Khoa NAS 2.3.1 — Android

App Material 3 có Tailscale tích hợp, chọn router từ danh sách tailnet, lưới/danh sách, ảnh/video trực tiếp, thumbnail/thời lượng, cắt/xoay ảnh lưu bản sao và sao lưu nền có thiết lập.
2.3.1 thêm **Hủy kết nối**, giới hạn chờ và bỏ kết quả trả muộn sau hủy. [Báo cáo lỗi kết nối 31/10](../../reports/2026-10-31-android-connection/README.md). Router ping Tailscale được nhưng cổng SMB chưa truy cập được từ máy kiểm tra; bản sửa app không khôi phục dịch vụ trên router.
Android tối thiểu 8.0/API 26. Chọn **arm64-v8a** cho điện thoại phổ biến;
**x86_64** dành cho LDPlayer và máy ảo tương ứng. Không cần cài app Tailscale riêng.

Đây là bản thử nghiệm ký bằng khóa Android debug cục bộ. Mã nguồn/build ở
[software/android](../../software/android/README.md), kết quả kiểm thử ở
[báo cáo 2.3](../../reports/2026-10-30-android-2.3/README.md).
Đã kiểm thử SMB nội bộ bản 2.0 trên máy ảo; sao lưu nền/codec/streaming NAS thật bản 2.3 và 4G còn cần xác minh. Chủ máy chọn cài 2.3 sau; bản này chưa cài lên Samsung. Sao lưu mặc định tắt. [Hướng dẫn cài](../../docs/INSTALL.md) · [Hướng dẫn ảnh và sao lưu](../../docs/ANDROID-BACKUP.md).

| APK | Bytes | SHA-256 |
|---|---:|---|
| [KhoaNAS-v2.3.1-arm64-v8a.apk](KhoaNAS-v2.3.1-arm64-v8a.apk) | 42947642 | `c32126ef25dce12ec3da178b4fd75402794745b21fdbcfe5be8e26d1f28361de` |
| [KhoaNAS-v2.3.1-x86_64.apk](KhoaNAS-v2.3.1-x86_64.apk) | 46075410 | `a5debfb259b51390f41610f859f0a5b1a498a7085ba2c0fc3a1c3c1ca340c8a2` |

APK 2.0 được giữ cho các báo cáo lịch sử. [Tải bản ARM64 mới nhất](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/releases/latest/download/KhoaNAS-Android.apk).

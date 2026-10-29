# Notice

Mã `scripts/kernel/dm-zero/src/dm-zero.c` lấy từ Linux stable v6.12.112, giữ thông tin tác giả và SPDX GPL-2.0-only; bản giấy phép nằm tại `scripts/kernel/dm-zero/COPYING`. APK dm-zero là bản tự dựng cho kernel đã ghi, không phải gói do OpenWrt ký.

Định dạng LMO và thuật toán SuperFastHash trong bộ biên dịch catalog được đối chiếu với `lmo.c` / `po2lmo.c` của OpenWrt LuCI (Jo-Philipp Wich; SuperFastHash của Paul Hsieh). View, RPC, manager và nguồn dịch tùy chỉnh nằm trong `router/luci-disk-manager`.

OpenWrt firmware binaries trong backup recovery là image dành cho Xiaomi Mi Router 3G / ramips-mt7621.

Licensing của firmware và package bên trong tuân theo OpenWrt và từng package tương ứng.

Đây là snapshot recovery theo thiết bị cụ thể. Luôn xác minh model, board và partition layout trước khi flash.

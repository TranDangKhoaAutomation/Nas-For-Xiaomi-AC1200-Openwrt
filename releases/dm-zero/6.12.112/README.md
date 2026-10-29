# dm-zero cho OpenWrt 25.12.6 / ramips-mt7621

Gói tự dựng, **không phải APK do OpenWrt ký**. Chỉ dùng với kernel và ABI tương thích; không ép nạp hoặc bỏ qua kiểm tra dependency khi đổi firmware.

- Kernel/vermagic: `6.12.112 SMP mod_unload MIPS32_R2 32BIT`.
- APK: `kmod-dm-zero-6.12.112.6.12.112-r1.apk`.
- SHA-256 APK: `529230dbedb980ba65d7c0184da267fda0b403c5ed0c7f67565e2ea14dda9b10`.
- SHA-256 ZIP artifact gốc: `7ed979a664709510cba17323e40915e7380abdd2215bd023bd5e26acab8fdc68`.
- [Workflow](../../../.github/workflows/build-dm-zero.yml), [run thành công](https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/actions/runs/40868849856).
- SDK OpenWrt 25.12.6 và mã nguồn Linux v6.12.112 được ghim SHA-256 trong workflow.
- [Mã module](../../../scripts/kernel/dm-zero/src/dm-zero.c), [mã gói](../../../scripts/kernel/dm-zero/Makefile).

`build-info.txt` ghi hash của bản `.ko` chưa strip trong artifact; APK chứa `.ko` đã strip nên không so hai tệp `.ko` đó với nhau. Kiểm tra hash APK sau khi chép sang router.

Trên đúng router, sau khi xác minh APK:

```sh
uname -r
sha256sum kmod-dm-zero-6.12.112.6.12.112-r1.apk
apk add --simulate --allow-untrusted ./kmod-dm-zero-6.12.112.6.12.112-r1.apk
apk add --allow-untrusted ./kmod-dm-zero-6.12.112.6.12.112-r1.apk
modprobe dm-zero
dmsetup targets
```

Phải có target `zero`. Trên router tham chiếu, module đã tự nạp và BitLocker tự mở sau reboot thật ngày 29/10/2026.

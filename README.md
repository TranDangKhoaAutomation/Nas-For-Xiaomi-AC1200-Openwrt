# Dựng NAS trên Xiaomi Mi Router 3G với OpenWrt và Tailscale

Hướng dẫn này ghi lại **cấu hình đã thực hiện và kiểm chứng ngày 12/10/2026** trên Xiaomi Mi Router 3G (MT7621), OpenWrt 25.12.5, kernel 6.12.94. Đi theo các bước từ trên xuống; ảnh ngay dưới từng bước là ảnh chụp thực tế. **Đọc trạng thái hiện tại dưới đây trước khi dùng NAS:** ổ USB đã thay đổi sau các ảnh và phép thử ban đầu. [Nhật ký đầy đủ](reports/2026-10-11-clean-rebuild/2026-10-12-full-journal.md) giữ các mốc chẩn đoán và thay đổi trước đó.

> **An toàn dữ liệu:** Cấu hình NAS ba share bên dưới là trạng thái **trước khi ổ USB bị ngắt lúc 16:04 ngày 12/10/2026**. Khi đó ba phân vùng đã được kiểm tra chỉ đọc trước khi dùng làm NAS mới; không thấy tệp NAS cũ. Không format, chia lại phân vùng, chạy `ntfsfix` hoặc gán UUID cũ cho ổ mới. `DATA3` lịch sử là NTFS thường, không phải volume PRIVATE VeraCrypt đã xác nhận.

## Trạng thái hiện tại của ổ thay thế — 12/10/2026

| Hạng mục | Kết quả mới nhất |
|---|---|
| Phạm vi chủ thiết bị chọn cho ổ mới | Chủ thiết bị yêu cầu **truy cập từ xa cả `sdb2` và `sdb3`**, và chọn **lưu khóa mở BitLocker trên router** để tự mở khi cắm ổ. `sdb2` đã hoạt động; `sdb3` còn chờ chủ thiết bị nhập mật khẩu kín trên Windows để kiểm tra và nạp khóa |
| `sdb2` — DANGKHOA | **PASS:** mount NTFS3 đọc/ghi tại `/mnt/dangkhoa` theo UUID `A8E46416E463E4D2`; KSMBD chỉ cho user `nas`, không guest. Windows ngoài LAN OpenWrt map `P:` tới `\\100.114.53.95\DANGKHOA`; tạo, đọc, xóa tệp thử thành công **trước reboot**. Sau reboot mới nhất, UUID tự mount lại và `P:` trở về trạng thái OK, mở được thư mục; phép thử ghi mới sau reboot chưa thực hiện |
| NAS1/NAS2/DATA3 cũ | **ĐÃ NGƯNG:** ổ mang ba UUID cũ không còn hiện diện; ba mục fstab cũ đã tắt và các share cũ được thay bằng `DANGKHOA`. Bản sao cấu hình cũ còn trên router tại `/root/*before-newdisk-20261012` |
| Ổ USB hiện thấy | Chỉ một ổ WDC 1 TB; sau reboot tên kernel đổi từ `/dev/sdb` sang `/dev/sda`, vì vậy cấu hình dùng UUID. `/dev/sda2` là NTFS nhãn `DangKhoa`, UUID `A8E46416E463E4D2`; `/dev/sda3` là BitLocker khoảng 100 GiB, UUID `1a518101-853b-45d0-ae99-beac1d47c63a` |
| `sdb3` — BitLocker | **FAIL trên kernel hiện tại:** mật khẩu thật đã được chủ thiết bị nhập kín, `cryptsetup --test-passphrase` xác minh đúng và lưu root-only trên router (`0700/0600`, ngoài Git). Khi tạo mapper, kernel báo `Cannot activate device, kernel dm-zero module is missing`; gói `kmod-dm` chính thức của bản firmware này không chứa `dm-zero.ko`. Hook hotplug đã tắt và init chưa enable. Chưa có mapper, mount hoặc share; không coi là tự mở được |
| Lỗi khi ổ cũ rời router | Chủ thiết bị xác nhận **chủ ý thay ổ**. Kernel ghi `USB disconnect` khi còn ghi, mất ghi đồng bộ, `Buffer I/O error` trên `sda2`–`sda4`; `ntfs3` đánh dấu các volume dirty. Khi cắm lại ổ cũ, cần kiểm tra filesystem trước khi cho ghi |
| Tailscale và quản trị | **PASS sau reboot mới nhất:** Tailscale tự chạy tại `100.114.53.95`; `rpcd`, `uhttpd`, `ksmbd` chạy, SSH qua tailnet và TCP 22/80/445 từ Windows ngoài LAN OpenWrt đều phản hồi; `fw4 check` đạt. WAN công cộng không mở SMB |

Chủ thiết bị xác nhận đã **thay ổ có chủ ý**. Nhật ký NAS trước đó không lưu serial nên không thể đối chiếu phần cứng bằng số serial. Các bước 1–8 bên dưới là nhật ký triển khai ổ cũ; **dùng bảng hiện tại để truy cập ổ mới**. Ba map Windows cũ `N:`, `M:`, `Z:` không còn truy cập được; ổ mới đang hoạt động là `P:`. Không coi BitLocker đã dùng được từ xa trước khi có phép thử thực tế.

## Sơ đồ và địa chỉ đang dùng

| Thành phần | Giá trị đã kiểm chứng |
|---|---|
| Router OpenWrt | LAN `192.168.1.1/24`; Tailscale `100.114.53.95`; MagicDNS ngắn `openwrt` trong tailnet `tail7e45a2.ts.net` |
| Quản trị | LuCI `http://100.114.53.95` hoặc `http://openwrt` khi Tailscale hoạt động; SSH qua tailnet bằng khóa |
| NAS từ máy Windows này | **Hiện tại:** `P:` → `DANGKHOA` (`\\100.114.53.95\DANGKHOA`), đã kiểm chứng đọc/ghi/xóa; các map `N:`, `M:`, `Z:` là lịch sử của ổ cũ |
| Bảo vệ | WAN từ chối kết nối vào; firewall chỉ cho TCP 22, 80, 445 và ICMP echo từ Tailscale; SMB yêu cầu user `nas`, không guest |

## Bước 1 — Xác nhận đúng router và kho gói

LuCI sau reset đã xác nhận đúng **Xiaomi Mi Router 3G** và OpenWrt 25.12.5. Kho APK đã cập nhật thành công, báo `11042 distinct packages available`. Giữ nguyên WAN DHCP và LAN `192.168.1.1/24`; không cần reset hoặc flash lại để làm theo các bước này. Tên repository có chữ AC1200 **không** phải tên phần cứng để chọn firmware.

Lệnh kiểm tra lại khi cần: `ubus call system board`, `ip -4 addr`, `ip -4 route`, `apk update`. OpenWrt 25.12 dùng **APK**, không dùng `opkg` cho hướng dẫn này.

![LuCI của router sau reset](reports/2026-10-11-clean-rebuild/screenshots/01-after-reset-software.png)

![APK cập nhật kho gói thành công](reports/2026-10-11-clean-rebuild/screenshots/02-apk-update-11042-packages.png)

## Bước 2 — Cài và bật Tailscale

Đã cài `tailscale 1.102.3-r1`, `kmod-tun` và `luci-app-tailscale-community` từ kho chính thức. Dịch vụ Tailscale được bật tự khởi động. Kiểm tra bằng `apk info tailscale`, `/etc/init.d/tailscale enabled`, `/etc/init.d/tailscale status` và `tailscale version`.

![APK cài Tailscale](reports/2026-10-11-clean-rebuild/screenshots/05-tailscale-apk-installed.png)

![Tailscale được bật trong Startup](reports/2026-10-11-clean-rebuild/screenshots/06-tailscale-init-enabled.png)

## Bước 3 — Đăng nhập tailnet và bật MagicDNS

Router đã được xác thực trên Tailscale Admin Console với tên `openwrt`, IP `100.114.53.95`; MagicDNS đã bật. Sau reboot, router vẫn giữ IP này và daemon tự kết nối lại. Trên router kiểm tra `tailscale status` và `tailscale ip -4`; trên Windows kiểm tra `tailscale status`, `tailscale ip -4` và `Resolve-DnsName openwrt`.

Không đưa auth key, state Tailscale hoặc mã đăng nhập vào tài liệu. Thiết bị Tailscale cũ `openwrt-nas` từng biến mất khỏi Admin Console theo audit; không tự xóa hoặc tái tạo node cũ.

![Admin Console thấy router Connected sau reboot Tailscale](reports/2026-10-11-clean-rebuild/screenshots/11-admin-router-connected-after-reboot.jpg)

![MagicDNS đang bật trong tailnet](reports/2026-10-11-clean-rebuild/screenshots/16-magicdns-enabled.jpg)

## Bước 4 — Nhận diện và kiểm tra ổ USB trước khi ghi

Ban đầu router thấy thiết bị USB nhưng chưa có `/dev/sdX`; cài `kmod-scsi-core` và `kmod-usb-storage` thì nhận ổ **WDC 1 TB**. `blkid` và `smartmontools` được dùng để nhận dạng phân vùng và đọc SMART. SMART trả `PASSED`; các bộ đếm reallocated, pending, uncorrectable và CRC tại thời điểm thử đều bằng 0. Kết quả SMART không thay thế kiểm tra hoặc sao lưu dữ liệu.

Đã gắn ba phân vùng **chỉ đọc** để kiểm tra trước khi chủ thiết bị chọn dùng ổ làm NAS mới. Mỗi phân vùng chỉ thấy `System Volume Information`; không có bằng chứng dữ liệu NAS cũ trên ổ hiện tại. Khi kiểm tra ổ khác, phải đối chiếu **UUID và dữ liệu thực tế** trước khi mount ghi, không suy từ số `/dev/sdaX`.

![Log LuCI nhận ổ WDC 1 TB và các phân vùng](reports/2026-10-11-clean-rebuild/screenshots/27-usb-disk-detected-in-luci-log.jpg)

## Bước 5 — Gắn ba phân vùng NTFS3 theo UUID

Sau khi được phép dùng ổ làm NAS mới, đã cài `kmod-fs-ntfs3` và `block-mount`. Fstab gắn tự động bằng **UUID** với tùy chọn `rw,uid=1000,gid=1000,umask=077,iocharset=utf8,noexec,nosuid,nodev`. Tài khoản hệ thống `nas` mang UID/GID 1000 và không có shell đăng nhập.

| Phân vùng | UUID hiện tại | Mount trên router | Share SMB | Ổ Windows |
|---|---|---|---|---|
| `Data` ~831,5 GiB | `2CF24485F24454EC` | `/mnt/nas` | `NAS1` | `N:` |
| `Data2` ~50 GiB | `549638DD9638C0F2` | `/mnt/nas2` | `NAS2` | `M:` |
| `Data3` ~50 GiB | `08820F9C820F8D7E` | `/mnt/data3` | `DATA3` | `Z:` |

Kiểm tra lại bằng `block info`, `uci show fstab`, `mount` và `df -h`; cả ba phải hiện `ntfs3 (rw)` trên đúng điểm gắn. Nếu UUID thay đổi, dừng và đối chiếu ổ trước khi sửa fstab.

![LuCI hiện ba UUID và mount NTFS3 đã bật](reports/2026-10-11-clean-rebuild/screenshots/29-luci-uuid-ntfs3-mounts.jpg)

## Bước 6 — Chia sẻ SMB có xác thực

Đã cài `kmod-fs-ksmbd`, `ksmbd-server`, `luci-app-ksmbd` và `shadow-useradd`; tạo ba share chỉ cho user `nas`, `read_only=no`, `guest_ok=no`, `create_mask=0600`, `dir_mask=0700`. SMBv1 và guest IPC tắt. KSMBD được cấu hình lắng nghe LAN và `tailscale0` bằng `interfaces = |INTERFACES| tailscale0`, `bind interfaces only = yes`.

**Không tạo interface `tailscale0` do netifd quản lý.** Lần thử `ifup tailscale` đã làm mất IP trên TUN và ngắt SSH/LuCI tailnet; sau khi bỏ interface thử nghiệm và restart daemon Tailscale, IP `100.114.53.95` cùng các dịch vụ hoạt động lại. Chi tiết sự cố nằm trong [nhật ký](reports/2026-10-11-clean-rebuild/2026-10-12-full-journal.md).

Mật khẩu SMB được lưu trên router và trong Windows Credential Manager của máy này, **không** lưu trong Git. Để cấp máy mới hoặc đổi mật khẩu SMB, đăng nhập SSH bằng khóa rồi chạy `ksmbd.adduser -u nas` và nhập bí mật tại prompt; cập nhật Credential Manager trên máy khách. Mật khẩu SMB độc lập với mật khẩu root LuCI.

![LuCI hiện ba share chỉ cho user nas, không guest](reports/2026-10-11-clean-rebuild/screenshots/28-luci-three-smb-shares.jpg)

## Bước 7 — Giới hạn firewall và thử từ ngoài LAN OpenWrt

Firewall WAN có `input REJECT`, `forward DROP`; không có rule mở TCP 22/80/445 từ WAN công cộng. Zone Tailscale chỉ cho SSH 22, LuCI HTTP 80, SMB 445 và ICMP echo tới router. Kiểm tra cấu hình bằng `fw4 check` và `fw4 print`, đối chiếu `input_wan` với `input_tailscale`.

Đã rút Ethernet trên Windows và dùng Wi-Fi `192.168.0.104/24`, khác LAN OpenWrt `192.168.1.0/24`. Trước khi dựng NAS, LuCI Overview, System Log và SSH đã hoạt động qua Tailscale; một lần thử còn xác nhận hai đầu ở hai IPv4 công cộng khác nhau. Sau reboot NAS, SMB tiếp tục hoạt động qua interface Tailscale từ Wi-Fi này. Đây là phép thử thực tế ngoài LAN OpenWrt, không chỉ là ping khi còn cùng LAN.

![LuCI Overview qua Tailscale trên Wi-Fi khác LAN OpenWrt](reports/2026-10-11-clean-rebuild/screenshots/25-luci-over-separate-wifi.jpg)

![LuCI System Log qua Tailscale trên Wi-Fi khác LAN OpenWrt](reports/2026-10-11-clean-rebuild/screenshots/26-luci-system-log-over-separate-wifi.jpg)

## Bước 8 — Map ổ Windows, reboot và kiểm chứng lại

Bật Tailscale trên Windows, mở **File Explorer → This PC**. Máy này đã map bền vững `N:` → `NAS1`, `M:` → `NAS2`, `Z:` → `DATA3`. Có thể dùng đường dẫn UNC trong bảng đầu README. Nếu Windows hiện **Unavailable** sau khi đăng nhập dù router và Tailscale đang chạy, dùng Terminal trên chính máy Windows để kích hoạt lại các map đã lưu (Credential Manager của máy này đã có tài khoản `nas`):

```powershell
net use N: \\100.114.53.95\NAS1 /persistent:yes
net use M: \\100.114.53.95\NAS2 /persistent:yes
net use Z: \\100.114.53.95\DATA3 /persistent:yes
```

Ngày 12/10, cả ba map từng hiện **Unavailable** trong phiên Windows hiện tại; chạy lại ba lệnh trên không cần nhập mật khẩu và `Get-SmbMapping` sau đó đều báo **OK**, `Test-Path` cả ba ổ trả `True`. Trên máy khác cần nhập mật khẩu SMB của user `nas` theo cách an toàn, không lấy mật khẩu từ README.

Đã reboot router sau khi dựng NAS. Hậu reboot, `tailscale`, `ksmbd`, `rpcd`, `uhttpd` đều chạy; IP tailnet giữ nguyên; ba phân vùng tự mount `ntfs3 (rw)`; `fw4 check` đạt. Từ Windows đang ở Wi-Fi ngoài LAN OpenWrt, cả ba share đều qua TCP 445 trên interface Tailscale. Thử **tạo, đọc lại và xóa** tệp nhỏ thành công trên từng share trước và sau reboot. LuCI phiên cũ yêu cầu đăng nhập lại sau reboot; giao diện đã được kiểm tra trước reboot NAS, còn sau reboot NAS đã kiểm tra SSH, TCP 80, SMB và daemon nhưng **chưa đăng nhập lại LuCI**.

![File Explorer sau reboot hiện NAS1 N:, NAS2 M: và DATA3 Z:](reports/2026-10-11-clean-rebuild/screenshots/30-windows-mapped-nas-drives.jpg)

## Bảng kết quả triển khai trước khi thay đổi ổ USB

| Tiêu chí | Kết quả tại lần kiểm tra 12/10/2026 |
|---|---|
| Tailscale tự chạy và giữ `100.114.53.95` sau reboot NAS | **PASS** |
| Mount tự động `ntfs3 (rw)` cho ba UUID sau reboot | **PASS** |
| SMB có xác thực, không guest, ghi/đọc/xóa cả ba share | **PASS** trước và sau reboot |
| Quản trị và SMB từ mạng ngoài LAN OpenWrt | **PASS** với Wi-Fi khác, Ethernet ngắt; LuCI/SSH đã thử trước reboot NAS, SMB thử sau reboot |
| Firewall WAN không mở 22/80/445 | **PASS** theo `fw4 check` và ruleset đã kiểm tra |
| Windows Tailscale và ba ổ NAS tại lần kiểm tra tiếp | **PASS:** backend `Running`, IP `100.85.51.71`; TCP 445 qua interface Tailscale; `N:`, `M:`, `Z:` được nối lại và mở được |
| LuCI đăng nhập giao diện sau reboot NAS | **CHƯA KIỂM CHỨNG LẠI:** tab hiện ở màn hình đăng nhập; HTTP 80 phản hồi, SSH và các daemon hoạt động. Cần chủ thiết bị tự đăng nhập để kiểm tra UI |
| Mật khẩu root LuCI mạnh | **CHƯA ĐẠT**; chủ thiết bị muốn tự đổi sau. Vào **System → Administration → Router Password**, tự đặt và lưu, rồi đăng nhập lại để xác nhận. Không chụp ô mật khẩu |
| FQDN MagicDNS trong Chrome | **FAIL phía client:** `openwrt.tail7e45a2.ts.net` từng báo `ERR_BLOCKED_BY_CLIENT`; DNS hệ điều hành và tên ngắn `openwrt` hoạt động. Chưa xác định tiện ích nào chặn |
| Khôi phục dữ liệu NAS cũ / PRIVATE | **KHÔNG THỰC HIỆN**; ổ hiện tại được chọn làm NAS mới, UUID khác và không thấy dữ liệu cũ |

Các dòng PASS về mount và SMB trong bảng này là **kết quả lịch sử trước 16:04 ngày 12/10/2026**, không phải trạng thái đang hoạt động. Trạng thái mới nhất ở bảng đầu README.

## Bước 9 — Ổ thay thế và tự mở BitLocker khi cắm

Ổ thay thế có phân vùng NTFS nhãn `DangKhoa` và phân vùng BitLocker. Tên thiết bị đã đổi từ `sdb2`/`sdb3` sang `sda2`/`sda3` sau reboot; dùng UUID để xác định. NTFS được mount đọc/ghi và chia sẻ tên `DANGKHOA`; trên Windows ngoài LAN OpenWrt, `P:` nối tới `\\100.114.53.95\DANGKHOA`. Phép thử tạo, đọc, xóa tệp đạt **trước reboot**; sau reboot `P:` tự nối lại và mở được thư mục. Hai ảnh dưới là ảnh mới của ổ thay thế, không phải ba share lịch sử ở bước 8.

![Ổ DANGKHOA P mở được trong File Explorer sau reboot](reports/2026-10-11-clean-rebuild/screenshots/31-current-dangkhoa-p-after-reboot.jpg)

![This PC hiển thị ổ mạng DANGKHOA P sau reboot](reports/2026-10-11-clean-rebuild/screenshots/32-current-dangkhoa-p-this-pc.jpg)

Để `sdb3` tự mở trên **router**, chủ thiết bị đã chọn lưu mật khẩu BitLocker trong `/etc/nas-bitlocker/passphrase` với quyền `0600`, thư mục quyền `0700`. Đây là sự đánh đổi: người có quyền root, có bản sao flash hoặc bản sao cấu hình chứa tệp đó có thể lấy mật khẩu và mở ổ. Đổi mật khẩu quản trị LuCI/root đang yếu trước khi coi mã hóa là lớp bảo vệ đáng tin cậy; không đưa mật khẩu BitLocker vào Git, ảnh, lệnh hoặc README. Giữ recovery key riêng với router và ổ, không chia sẻ backup cấu hình có chứa khóa. Windows auto-unlock gắn với máy/tài khoản Windows, không tự chuyển sang OpenWrt. [Microsoft BitLocker FAQ](https://learn.microsoft.com/en-us/windows/security/information-protection/bitlocker/bitlocker-key-management-faq), [cryptsetup BITLK](https://gitlab.com/cryptsetup/cryptsetup/-/blob/main/man/cryptsetup.8.adoc?ref_type=heads).

Bộ quản lý trên router đã cài tại `/usr/sbin/nas-bitlocker-manager`, chỉ nhận UUID `1a518101-853b-45d0-ae99-beac1d47c63a`. Chủ thiết bị đã chạy script dưới đây: prompt kín kiểm tra fingerprint SSH đã ghim, truyền mật khẩu qua SSH stdin, thử `cryptsetup --test-passphrase` thành công, rồi lưu tệp quyền root trên router. Lệnh được giữ ở đây để dùng khi cần nạp lại khóa; **không cần chạy lại lúc này**.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\Nas-Router\Nas-For-Xiaomi-AC1200-Openwrt\scripts\provision-bitlocker-passphrase.ps1"
```

**Kết quả mở thật: FAIL do thiếu `dm-zero`.** Sau khi xác minh mật khẩu, `cryptsetup open --type bitlk` báo `device-mapper: reload ioctl ... Invalid argument` và `Cannot activate device, kernel dm-zero module is missing`. Gói `kmod-dm` chính thức trên kernel 6.12.94 chứa `dm-crypt`, `dm-log`, `dm-mirror`, `dm-mod`, `dm-region-hash`, nhưng không có `dm-zero.ko`; kho APK cũng không có gói `kmod-dm-zero` hoặc `dislocker`. OpenWrt hiện đặt `CONFIG_DM_ZERO=n` trong `package/kernel/linux/modules/block.mk`. Hook được chuyển ra `/root/95-nas-bitlocker.disabled`, init chưa enable; vì vậy cắm ổ sẽ **không tự mở** cho tới khi có module tương thích được kiểm thử. Chưa tạo share SMB cho phân vùng mã hóa để tránh trình bày một thư mục rỗng như dữ liệu thật. Không rút ổ khi đang ghi; dừng kết nối SMB và tháo mount trước. [Mã nguồn cryptsetup kiểm tra dm-zero](https://gitlab.com/cryptsetup/cryptsetup/-/blob/main/lib/bitlk/bitlk.c), [tài liệu OpenWrt về kernel module](https://openwrt.org/docs/guide-developer/packages).

| Kiểm tra sau reboot ổ thay thế | Kết quả |
|---|---|
| Tailscale IP `100.114.53.95`, SSH, LuCI HTTP, SMB TCP 445 qua Wi-Fi ngoài LAN OpenWrt | **PASS** qua CLI/kết nối; chưa đăng nhập lại LuCI UI |
| `rpcd`, `uhttpd`, `tailscale`, `ksmbd`, `fw4 check` | **PASS** |
| NTFS UUID `A8E46416E463E4D2` tự mount `ntfs3 rw`; Windows `P:` OK và mở thư mục | **PASS**; ghi/đọc/xóa tệp chỉ được kiểm chứng trước reboot |
| BitLocker UUID `1a518101-853b-45d0-ae99-beac1d47c63a` tự mở, mount, SMB | **FAIL**: thiếu kernel target `dm-zero`; chưa có mapper/share |

### Nếu mã hóa hoặc giải mã phân vùng khác sau này

**Trạng thái đã thay đổi:** Router hiện nhận diện `sdb3` là BitLocker, nhưng chưa mở khóa hoặc mount. Nếu sau này mã hóa phân vùng khác, sao lưu dữ liệu trước, dừng share tương ứng, `sync`, tháo mount sạch trên router rồi mới cắm ổ vật lý sang Windows. Giữ khóa khôi phục 48 chữ số ở nơi riêng, kiểm tra tìm được khóa trước khi tháo ổ. Ổ mạng `N:`, `M:`, `Z:` là share SMB, không phải ký tự phân vùng vật lý để bật BitLocker trực tiếp. Phân vùng đã mã hóa sẽ không còn mount thẳng bằng cấu hình NTFS3 cũ.

Để **mở khóa** volume trên Windows, dùng giao diện BitLocker hoặc `manage-bde -unlock E: -password` với đúng ký tự volume thực tế. Để **giải mã vĩnh viễn**, sau khi mở khóa dùng `manage-bde -off E:` và chờ `manage-bde -status E:` báo hoàn tất. Không ghi mật khẩu hoặc recovery key vào lệnh, ảnh hay repo. Xem [Microsoft: mở khóa](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/manage-bde-unlock), [giải mã](https://learn.microsoft.com/en-us/windows-security/operating-system-security/data-protection/bitlocker/operations-guide), [tìm recovery key](https://support.microsoft.com/en-us/windows/security/encryption/find-your-bitlocker-recovery-key).

`cryptsetup --type bitlk` đã được **cài** trên router và đọc được metadata BitLocker của `sdb3`; khả năng mở khóa, mount và tốc độ đọc/ghi **chưa được kiểm chứng**. Xem [tài liệu cryptsetup BITLK](https://gitlab.com/cryptsetup/cryptsetup/-/blob/main/man/cryptsetup.8.adoc?ref_type=heads) và [OpenWrt ksmbd](https://openwrt.org/docs/guide-user/services/nas/ksmbd).

## Tài liệu và ảnh lưu trữ

- [Nhật ký đầy đủ 11–12/10/2026](reports/2026-10-11-clean-rebuild/2026-10-12-full-journal.md): chi tiết lệnh, lỗi LuCI, thử nghiệm và ảnh bổ sung theo thời gian.
- [README trước factory reset](reports/2026-10-11-clean-rebuild/README-before-reset.md): cấu hình và UUID **lịch sử**, không dùng để tự phục hồi ổ hiện tại.
- [Thư mục ảnh gốc](reports/2026-10-11-clean-rebuild/screenshots/): giữ nguyên tên ảnh và thứ tự chụp để đối chiếu. Các tài liệu NAS cũ trong `docs/` cũng cần đối chiếu với bảng UUID hiện tại trước khi áp dụng.

Không lưu mật khẩu root, mật khẩu SMB, khóa khôi phục, Tailscale auth key hoặc session token trong repository.

# Khôi phục OpenWrt và Tailscale — 11/10/2026

> Báo cáo và hướng dẫn triển khai có kiểm chứng. Các bước CHƯA THỰC HIỆN chỉ là hướng dẫn, không được xem là đã chạy.
>
> **Đúng phần cứng:** Xiaomi Mi Router 3G, board xiaomi,mi-router-3g, MediaTek MT7621. Tên repository có chữ AC1200 không phải căn cứ chọn firmware; không flash ảnh cho model khác.
>
> **Trạng thái mới nhất:** xem bảng ngay dưới đây và các mục kiểm chứng ngày 12/10/2026 ở cuối tài liệu. Những bảng cũ là nhật ký tại thời điểm thực hiện, được giữ lại để đối chiếu.

## Tóm tắt trạng thái đã kiểm chứng — 12/10/2026, 11:34 ICT

| Tiêu chí | Trạng thái hiện tại |
|---|---|
| OpenWrt và Tailscale sau reboot | **PASS:** router hoạt động hơn 10 giờ, Tailscale tự chạy và giữ `100.114.53.95`; `rpcd`/`uhttpd` chạy |
| Quản trị từ Windows qua tailnet | **PASS:** SSH bằng khóa, LuCI qua `http://100.114.53.95` và tên ngắn MagicDNS `http://openwrt`; System Log tải được. Log router ghi nguồn `100.85.51.71` |
| Firewall | **PASS theo cấu hình và kiểm tra hiện tại:** WAN input REJECT/forward DROP; tailnet chỉ được TCP 22/80 và ICMP echo tới router; không quảng bá subnet/exit node |
| FQDN MagicDNS trong Chrome | **FAIL phía client:** `openwrt.tail7e45a2.ts.net` bị `ERR_BLOCKED_BY_CLIENT`; tên ngắn `openwrt` đã hoạt động trên cùng tab |
| Quản trị qua Internet ngoài LAN OpenWrt | **PASS:** Ethernet ngắt; Windows dùng Wi-Fi `10.31.110.127/24` qua gateway `10.31.110.104`, ngoài LAN router `192.168.1.0/24`. `tailscale netcheck` cho thấy hai đầu có IPv4 công cộng khác nhau; Tailscale chuyển tiếp qua DERP `hkg`. SSH bằng khóa, LuCI Overview/System Log qua IP tailnet và tên ngắn MagicDNS đều hoạt động. Không kết luận hai đầu ở hai ISP khác nhau |
| Mật khẩu root mạnh | **HOÃN THEO CHỦ THIẾT BỊ:** chủ thiết bị sẽ tự đổi sau; SSH root bằng mật khẩu đã tắt, LuCI vẫn dùng mật khẩu hiện tại |
| NAS/HDD | **KHÔNG CAN THIỆP:** chưa thao tác dữ liệu hoặc filesystem của ổ NAS |

**Quản trị ngoài LAN đã đạt.** Mật khẩu root mới được chủ thiết bị hoãn để tự đặt sau, nên tiêu chí mật khẩu mạnh chưa đạt và không được gộp vào PASS. Chưa xác định chắc nguyên nhân gốc của lỗi LuCI cũ hoặc thành phần Chrome chặn FQDN MagicDNS; đường quản trị bằng IP tailnet và tên ngắn đã hoạt động. Thiết bị Tailscale cũ `openwrt-nas` đã biến mất khỏi Admin Console; chi tiết audit ở phần sau, không xóa hoặc đăng ký lại trong lần làm việc này.

## Trạng thái thực tế sau khi reset

| Bước | Tình trạng | Bằng chứng |
|---|---|---|
| Factory Reset | ĐÃ XÁC MINH | Uptime trở về ~30 phút, Wi-Fi 2.4/5 GHz tắt mặc định |
| Firmware | ĐÃ XÁC MINH | OpenWrt 25.12.5 r33051-f5dae5ece4, kernel 6.12.94 |
| LAN | ĐÃ XÁC MINH | 192.168.1.1; LAN1 link 1 GbE |
| WAN | ĐÃ XÁC MINH | DHCP 10.2.28.41/24, gateway 10.2.28.1, link 100 Mb/s |
| Kho APK | ĐÃ XÁC MINH | LuCI cập nhật được, trả về OK: 11042 distinct packages available |
| Đăng nhập root | ĐÃ XÁC MINH | SSH dùng mật khẩu được chủ thiết bị cung cấp, không ghi bí mật vào repo; cần nâng độ mạnh |
| Cài gói Tailscale | ĐÃ XÁC MINH | LuCI APK: tailscale 1.102.3-r1 + kmod-tun; OK: 43.3 MiB in 159 packages |
| Login Tailscale | ĐANG XỬ LÝ | LuCI Login đang chờ URL; node chưa được xác thực |
| Truy cập từ mạng ngoài | CHƯA KIỂM THỬ | Chưa có Tailscale IPv4 mới được xác minh |
| NAS/USB/VeraCrypt | CHƯA KHÔI PHỤC | Bảo toàn dữ liệu, không ghi lên ổ lỗi |

## Ảnh chụp thao tác (ảnh thực từ máy tính)

Ảnh đặt trong thư mục reports/2026-10-11-clean-rebuild/screenshots/.

### 01 — Giao diện quản trị sau reset

![LuCI sau factory reset](reports/2026-10-11-clean-rebuild/screenshots/01-after-reset-software.png)

### 02 — Cập nhật kho APK

![APK update](reports/2026-10-11-clean-rebuild/screenshots/02-apk-update-11042-packages.png)

**Kết quả xác minh:** LuCI hiện ra dòng OK: 11042 distinct packages available.

Các ảnh ở các bước sau chỉ được thêm vào README sau khi đã thao tác, và phải kiểm tra file PNG thực sự được lưu.

## Mục tiêu cài đặt

- Giữ OpenWrt hiện tại, WAN DHCP và LAN 192.168.1.1/24.
- Đặt mật khẩu root an toàn và bảo vệ SSH; tuyệt đối không đưa mật khẩu hoặc Tailscale auth key vào Git.
- Cài Tailscale từ kho APK **chính thức OpenWrt 25.12**, tự động khởi động.
- Truy cập LuCI/SSH từ tailnet (hoặc MagicDNS) thay vì mở cổng quản trị ra WAN.
- Chỉ quảng bá subnet 192.168.1.0/24 khi cần quản lý các máy khác trong LAN. Không bật exit node mặc định.
- NAS/SMB chỉ sử dụng sau khi phần cứng USB và NTFS được kiểm tra độc lập.

## Các bước thực hiện (lệnh mẫu — chưa mặc nhiên được chạy)

### 1. Đặt password root

Vào System → Administration → Router Password; đặt mật khẩu mạnh, lưu vào trình quản lý mật khẩu riêng tư, xác minh bằng cách đăng nhập lại LuCI. Không chụp màn hình trường chứa mật khẩu.

### 2. Kiểm tra sức khỏe OpenWrt

~~~sh
ubus call system board
ip -4 addr
ip route
ping -c 3 1.1.1.1
nslookup openwrt.org
df -h
free -m
~~~

### 3. Cài Tailscale trên OpenWrt 25.12 (dùng APK, KHÔNG dùng opkg)

~~~sh
apk update
apk add tailscale
/etc/init.d/tailscale enable
/etc/init.d/tailscale start
tailscale version
~~~

### 4. Đăng ký router vào Tailscale

~~~sh
tailscale up --hostname=openwrt-mi-router-3g --accept-dns=false
tailscale status
tailscale ip -4
tailscale netcheck
~~~

Mở URL auth sinh ra bởi lệnh tailscale up và xác nhận trên tài khoản người dùng. Không giả định IP trước reset 100.91.1.101 còn hiệu lực.

### 5. Firewall và quản trị an toàn

Tạo interface quản lý cho tailscale0 và firewall zone riêng theo hướng dẫn OpenWrt. Chỉ cho phép inbound qua tailscale0 tới dịch vụ cần (LuCI/SSH, SMB nếu NAS sẵn sàng). Không mở cổng 22, 80, 443 hoặc 445 trực tiếp từ WAN. Subnet router cần cấu hình forward/NAT, quảng bá route và duyệt trong Tailscale Admin; không cần bật cho truy cập chỉ trên router.

### 6. Kiểm tra sau triển khai

~~~sh
/etc/init.d/tailscale status
tailscale status
tailscale ip -4
tailscale netcheck
logread | tail -n 100
~~~

Test trên điện thoại sử dụng 4G/5G hoặc thiết bị ở mạng khác, kiểm tra SSH/LuCI, ACL, reconnect, reboot, tự khởi động. Build/installed không thay thế kiểm tra thực tế.

## Lỗi NAS trước reset: không tự khôi phục

Trước reset, kernel ghi USB disconnect và Buffer I/O error trên sda1; ntfs3 đánh dấu volume dirty. Script giám sát NAS trước đây lặp lệnh dừng ksmbd mỗi 5 giây khi không có share mount. Không chạy format, ntfsfix, fsck hoặc mount ghi dữ liệu lên ổ trước khi kiểm tra/backup dữ liệu. Kiểm tra cáp/box/nguồn, SMART và filesystem riêng trước khi phục hồi NAS1/NAS2/PRIVATE VeraCrypt.

## Kiểm soát rủi ro

1. Chụp ảnh mỗi mốc UI đã thực hiện; ẩn dữ liệu xác thực.
2. Không restore nguyên cấu hình cũ từ trước reset.
3. Giữ kết nối LAN trong toàn bộ quá trình chỉnh firewall/VPN.
4. Sau khi cài đặt, kiểm tra reboot, test lại Internet/DHCP/SSH/LuCI và lưu log kết quả; nêu rõ phần chưa test.
5. Không đưa state Tailscale, keys, passphrase VeraCrypt vào repo.

## Tài liệu tham khảo

- OpenWrt Tailscale: https://openwrt.org/docs/guide-user/services/vpn/tailscale/start
- OpenWrt downloads: https://downloads.openwrt.org/
- Tailscale subnet router: https://tailscale.com/docs/features/subnet-routers
- Tailscale auth keys: https://tailscale.com/docs/features/access-control/auth-keys

## Lưu trữ lịch sử

Bản README trước reset được sao lưu nguyên vẹn tại reports/2026-10-11-clean-rebuild/README-before-reset.md. Các thông số Tailscale, SMB và mount cũ chỉ mang tính lịch sử, chưa được chứng thực lại sau Factory Reset. Các thư mục dự án hiện có khác được giữ nguyên.


## Nhật ký triển khai tiếp nối (12/10/2026, sau factory reset)

Các thao tác sau được thực hiện trực tiếp trên **một tab LuCI** hiện có bằng công cụ điều khiển trình duyệt, kết hợp chẩn đoán SSH. Thư mục NAS/USB chưa được mount, format, fsck, ntfsfix hoặc ghi dữ liệu.

### Bằng chứng đã kiểm tra

| Hạng mục | Trạng thái kiểm chứng | Lệnh / giao diện |
|---|---|---|
| SSH host fingerprint | ED25519 `SHA256:qXMHQKUxALpxCzg0HamL7k1HXT38gzDdK5LEGvyqOVA` | SSH đã ghim khóa host sau reset; khóa cũ trong known_hosts được giữ nguyên |
| SSH root | Thành công | SSH đăng nhập qua địa chỉ LAN bằng thông tin chủ thiết bị cung cấp |
| Firmware | OpenWrt 25.12.5, kernel 6.12.94, Xiaomi Mi Router 3G | `ubus call system board` |
| LAN | 192.168.1.1/24, LAN1 liên kết 1 GbE | `uci show network.lan`, LuCI Overview |
| WAN | DHCP 10.2.28.22/24, gateway 10.2.28.1 | `uci show network.wan`, `ip -4 route` |
| Internet / DNS | ping 1.1.1.1: 2/2; DNS openwrt.org thành công | `ping -c 2 -W 2 1.1.1.1`; `nslookup openwrt.org` |
| Firewall WAN | `input REJECT`, `forward DROP` trên zone WAN; không thấy redirect trong bản audit | `uci show firewall` |
| APK index | 11042 gói | Software → Update Lists; lệnh chạy bởi LuCI: `apk update` |
| Gói Tailscale | Cài thành công `tailscale 1.102.3-r1`, `kmod-tun` | Software → install; lệnh chạy bởi LuCI: `apk add tailscale` |
| Quản trị LuCI Tailscale | Cài thành công `luci-app-tailscale-community` | LuCI `apk add luci-app-tailscale-community` |
| Tailscale autostart | Hiện `Đã bật` tại System → Startup, priority 80 | LuCI Startup; thao tác Start đã gửi |
| Runtime Tailscale | **CHƯA ĐẠT**: Tailscale LuCI health check báo stopped, Login đang chờ URL | Services → Tailscale |
| Tailscale cấu hình | Backend `nftables`; Accept Routes, Exit Node, Advertise Exit Node, Shields Up, Tailscale SSH, Disable MagicDNS đều chưa bật | LuCI Tailscale → General Settings |
| MagicDNS/tailnet | **CHƯA KIỂM CHỨNG**: phải đăng nhập Tailscale và kiểm tra DNS trong admin console | Không kết luận từ checkbox LuCI |
| Remote access | **CHƯA KIỂM THỬ**: không có Tailscale IPv4 xác minh | Cần test qua thiết bị ngoài LAN |
| Khởi động lại | **CHƯA KIỂM THỬ** kể từ khi cài gói | Không giả định daemon tự kết nối lại |
| NAS | Không thao tác | Giữ nguyên ổ USB và filesystem |

### Ảnh chụp thực tế mới

![LuCI APK cập nhật lại kho](reports/2026-10-11-clean-rebuild/screenshots/04-apk-update-rechecked.png)

![LuCI cài Tailscale 1.102.3](reports/2026-10-11-clean-rebuild/screenshots/05-tailscale-apk-installed.png)

![Startup Tailscale đã bật](reports/2026-10-11-clean-rebuild/screenshots/06-tailscale-init-enabled.png)

![Cài trang LuCI Tailscale](reports/2026-10-11-clean-rebuild/screenshots/07-tailscale-luci-app-install.png)

![Trạng thái Tailscale trước đăng nhập](reports/2026-10-11-clean-rebuild/screenshots/08-tailscale-before-login.png)

### Kiểm tra tiếp theo

1. Khắc phục daemon stopped dựa trên log thực tế. Gói Tailscale phát log cleanup `iptables` và `ip6tables` không tồn tại; trên OpenWrt 25.12 dùng nftables, cần phân biệt thông báo cleanup với lỗi khởi động thật. Không thêm iptables một cách ngẫu nhiên.
2. Sau khi `tailscale status` hoạt động: login với hostname riêng, `--accept-dns=false` nếu thiết bị giữ vai trò router; tài khoản Tailscale bắt buộc được chủ thiết bị xác thực.
3. Chỉ tạo zone/interface `tailscale0` cho quyền quản trị router. **Không quảng bá LAN subnet, không bật exit node, không cho phép forwarding tailnet→LAN** khi chưa có yêu cầu mở rộng.
4. Chỉ mở LuCI/SSH từ LAN và tailnet hợp lệ; không thêm rule WAN cho TCP 22, 80, 443. Cân nhắc khóa SSH key-based thay vì mật khẩu yếu.
5. Test port qua Tailscale IP và tên MagicDNS, xem firewall counters, test mạng di động tách LAN, reboot rồi kiểm tra reconnect; mọi mục chưa chạy vẫn đánh dấu chưa kiểm chứng.

**Lưu ý an toàn:** Không lưu mật khẩu quản trị, auth URL/token, thiết lập state chứa khóa hoặc private SSH key vào repository.


### Cập nhật chẩn đoán: LuCI RPC phản hồi chậm

- Sau khi nhấn **Services → Tailscale → Login**, dialog `Requesting Login URL... Please wait.` tồn tại mà chưa trả URL. Trước đó health check LuCI báo **Tailscale is stopped**.
- Các view **Status → System Log** và **System → Reboot** hiện chỉ hiển thị `Đang tải…`, chưa hiển thị log hay nút reboot. **Không tuyên bố đã reboot** hoặc đã xử lý root cause.
- Kiểm tra TCP từ Windows tới router sau khi phát sinh lỗi: TCP **22 mở**, **80 mở**, **443 timeout**. Kết quả này chỉ chứng minh socket LAN còn truy cập, không chứng minh rpcd hay Tailscale khỏe.
- **Chưa sửa firewall, không bật route LAN, không mở cổng WAN.** Không can thiệp NAS.
- Ảnh minh họa khi System Log chưa tải:

![LuCI System Log stuck loading](reports/2026-10-11-clean-rebuild/screenshots/09-luci-system-log-loading.png)

#### Chẩn đoán tiếp theo — lệnh dự kiến, CHƯA CHẠY sau sự cố

~~~sh
/etc/init.d/tailscale status
tailscale status
ps w | grep -E '[t]ailscale|[r]pcd'
logread | grep -Ei 'tailscale|procd|rpcd|oom|error' | tail -n 100
lsmod | grep -i tun
nft list ruleset
df -h
~~~

**Mức xác nhận:** Gói APK đã cài, autostart đã bật, nhưng chưa chứng minh daemon hoạt động, đăng nhập tailnet, truy cập từ bên ngoài, MagicDNS hoặc tự kết nối sau reboot. Tránh khẳng định OpenWrt+Tailscale đã hoàn tất khi chưa có bằng chứng tương ứng.

## Kiểm chứng sau reboot ngày 12/10/2026

Thực hiện trực tiếp bằng SSH, PowerShell trên Windows, Plugin Bridge Web trên **một tab LuCI hiện có** và tab Tailscale Admin Console. Không format, mount, sửa hoặc xóa dữ liệu NAS/HDD; không reset hay flash router. Bảng này cập nhật các trạng thái cũ ở phía trên, nhưng giữ nguyên nhật ký cũ.

| Tiêu chí | Kết quả | Bằng chứng thực tế |
|---|---|---|
| Đúng router/firmware | **PASS** | `ubus call system board`: Xiaomi Mi Router 3G, OpenWrt 25.12.5, kernel 6.12.94 |
| SSH host key sau reset | **PASS** | ED25519 `SHA256:qXMHQKUxALpxCzg0HamL7k1HXT38gzDdK5LEGvyqOVA` trùng fingerprint đã ghi trước đó; dùng tệp known_hosts riêng, không ghi đè khóa cũ |
| `rpcd`, `uhttpd`, log và tài nguyên | **PASS cho kiểm tra hiện tại** | Hai dịch vụ báo `running`; `logread` qua SSH đọc được; load trước reboot 0.00 và RAM khả dụng khoảng 149 MB, overlay dùng 15%; không thấy bằng chứng OOM hoặc tiến trình chết |
| Trang System Log và Reboot | **PASS sau reboot** | Mở từ menu LuCI qua IP Tailscale: System Log thoát `Đang tải…`; Reboot hiển thị nút thao tác. Không bấm reboot lần hai. Yêu cầu điều hướng trực tiếp bằng công cụ đôi lúc trả 403 và yêu cầu đăng nhập lại; chưa xác định chắc nguyên nhân của hiện tượng phiên này |
| Router Tailscale runtime | **PASS** | `/etc/init.d/tailscale status` → `running`; `tailscale status` có `openwrt`; `tailscale ip -4` → `100.114.53.95`; LuCI hiển thị RUNNING |
| Router Tailscale tự chạy sau reboot | **PASS** | Đã chạy `sync; reboot`; uptime từ khoảng 56 phút về 1 phút. Sau reboot `/etc/rc.d/S80tailscale` vẫn tồn tại, daemon `running`, cùng IP `100.114.53.95`; Admin Console báo `Connected` |
| LAN, WAN, DNS, Internet sau reboot | **PASS** | LAN `192.168.1.1/24`, WAN DHCP `10.2.28.22/24`, gateway `10.2.28.1`; ping `1.1.1.1` 2/2; `nslookup openwrt.org` thành công; router phân giải `openwrt.tail7e45a2.ts.net` ra `100.114.53.95` |
| Windows Tailscale | **PASS trong phiên hiện tại** | Trước đó service chạy nhưng CLI `NoState`, adapter chỉ có `169.254.83.107`. Sau khi mở `tailscale-ipn.exe`, CLI chuyển `Running`, IP `100.85.51.71`. Đã đặt `--unattended=true`; sau khi đóng tiến trình GUI, service vẫn Running và `tailscale ping` tới router thành công |
| MagicDNS trên Windows | **PASS ở mức DNS hệ điều hành/CLI** | Đã áp `tailscale set --accept-dns=true` và xóa DNS cache; NRPT trỏ `tail7e45a2.ts.net` đến `100.100.100.100`; `Resolve-DnsName` và SSH bằng tên đầy đủ đều thành công. Chrome hiển thị trang trắng khi mở LuCI bằng tên này; network event ghi `net::ERR_BLOCKED_BY_CLIENT` (chưa xác định thành phần chặn). **LuCI qua tên trong Chrome chưa đạt**; LuCI qua IP Tailscale hoạt động |
| SSH/LuCI qua tailnet | **PASS từ máy Windows hiện tại** | `Test-NetConnection` TCP 22/80 dùng interface `Tailscale`, địa chỉ nguồn `100.85.51.71`; SSH bằng public key đến `100.114.53.95` và tên MagicDNS thành công; LuCI qua `http://100.114.53.95` tải Overview, System Log và Reboot |
| SSH key của người dùng | **PASS** | Đã thêm **public key** hiện có, fingerprint `SHA256:a5AQZ0oxGbjC4J3O6x+PjFgUihp4H3VMszYMEyrbsFA`, vào `/etc/dropbear/authorized_keys`; SSH key đăng nhập thành công qua LAN và tailnet. Đã đặt `dropbear.main.RootPasswordAuth='off'` và xác nhận SSH key vẫn hoạt động |
| Firewall quản trị | **PASS cho rule và phép thử hiện tại** | Zone `tailscale` gắn `tailscale0`: input/forward REJECT, chỉ cho phép TCP 22/80 và ICMP echo tới router. `fw4 check` đạt trước và sau reboot; counter rule cho phép và từ chối tăng. TCP 53 hoạt động trên LAN nhưng bị từ chối qua tailnet. WAN vẫn `input REJECT`, `forward DROP`, không thêm rule WAN cho 22/80/443; không quảng bá subnet hoặc bật exit node |
| Truy cập thực sự từ Internet ngoài LAN | **CHƯA KIỂM CHỨNG** | Windows vẫn nối Ethernet `192.168.1.185` vào LAN router; Wi-Fi không kết nối. Dù gói quản trị đi qua interface Tailscale, Tailscale chọn endpoint trực tiếp tại cùng địa điểm (`10.2.28.22` trong một lần ping, `192.168.1.185` trong log sau đó). Chưa thử bằng điện thoại 4G/5G hoặc máy ở mạng khác |
| Thiết bị Tailscale cũ `openwrt-nas` | **FAIL — không còn trong danh sách** | Admin Console lúc đầu có `openwrt-nas` (`100.91.1.101`) và `galaxy-a15`; sau đó còn hai máy. Configuration logs ghi `Delete node` cho `openwrt-nas`, `galaxy-a15` và node Windows cũ lúc **00:40 ngày 12/10/2026**, actor hiển thị tên tài khoản. Phiên thao tác này không gửi lệnh xóa; log không đủ để xác định phiên nào gây ra việc xóa. Không tự tạo lại hoặc xóa thêm thiết bị |
| Mật khẩu root LuCI | **FAIL — cần đổi** | Mật khẩu chủ thiết bị cung cấp còn yếu. SSH root bằng mật khẩu đã tắt; LuCI vẫn dùng mật khẩu này qua LAN/tailnet. Cần đổi bằng giao diện nhập bí mật riêng, không lưu trong repository |
| NAS/HDD | **KHÔNG CAN THIỆP** | Không chạy format, mount, fsck, ntfsfix, thao tác SMB hoặc sửa dữ liệu ổ đĩa |

### Ảnh chụp mới đã lưu và kiểm tra

![Tailscale RUNNING trước reboot](reports/2026-10-11-clean-rebuild/screenshots/10-luci-tailscale-running-before-reboot.png)

![Admin Console: router và Windows Connected sau reboot](reports/2026-10-11-clean-rebuild/screenshots/11-admin-router-connected-after-reboot.jpg)

![Tailscale RUNNING sau reboot](reports/2026-10-11-clean-rebuild/screenshots/12-luci-tailscale-running-after-reboot.png)

![LuCI Overview qua IP Tailscale](reports/2026-10-11-clean-rebuild/screenshots/13-luci-over-tailscale-ip.png)

![Trang Reboot LuCI tải được qua Tailscale](reports/2026-10-11-clean-rebuild/screenshots/14-luci-reboot-page-after-reboot.png)

![Audit log ghi việc xóa các node cũ lúc 00:40](reports/2026-10-11-clean-rebuild/screenshots/15-tailscale-audit-old-nodes-deleted.jpg)

![MagicDNS đang bật cho tailnet](reports/2026-10-11-clean-rebuild/screenshots/16-magicdns-enabled.jpg)

### Giới hạn còn lại

1. Chưa thử SSH/LuCI từ một mạng ngoài LAN thực sự. Cần thử bằng thiết bị đang dùng 4G/5G hoặc một mạng khác, rồi xác nhận interface Tailscale, SSH và HTTP LuCI.
2. Chrome chưa tải được LuCI bằng tên MagicDNS: request bị `net::ERR_BLOCKED_BY_CLIENT`; DNS hệ điều hành, SSH theo tên và LuCI theo IP Tailscale vẫn đạt. Chưa xác định chính xác extension/chính sách phía trình duyệt gây chặn; không gộp phép thử này vào PASS của trình duyệt.
3. Nguyên nhân gốc của các lần LuCI `Đang tải…`/403 trước đây chưa được chứng minh; sau reboot, các trang được thử từ menu đã tải. Theo dõi thêm nếu lỗi tái phát.
4. Đổi mật khẩu root LuCI sang mật khẩu mạnh qua một kênh nhập bí mật an toàn. Không lưu mật khẩu vào README, ảnh hoặc log.
5. `openwrt-nas` và `galaxy-a15` không còn trong Admin Console; cần chủ tailnet kiểm tra audit/thiết bị cũ nếu muốn đăng ký lại. Không có thao tác khôi phục danh tính node cũ trong lần kiểm tra này.

### Kiểm tra tiếp lúc 01:21–01:23 ngày 12/10/2026

| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| Router và Windows Tailscale sau thêm 32 phút uptime | **PASS** | Router vẫn `running`, IP `100.114.53.95`; Windows IP `100.85.51.71`, `Resolve-DnsName openwrt.tail7e45a2.ts.net` trả `100.114.53.95`; SSH bằng khóa qua tailnet thành công |
| Dịch vụ LuCI và tải máy | **PASS tại thời điểm kiểm tra** | `rpcd` và `uhttpd` cùng `running`; load 0.10/0.08/0.08, RAM available 147900 KiB; không thấy OOM trong phần log mới |
| LuCI System Log | **PASS trong lần thử này** | Cùng tab OpenWrt chuyển từ tên MagicDNS sang IP tailnet, Overview và System Log đều hết `Đang tải…`, hiện nội dung log. Ảnh 17 |
| MagicDNS ở lớp mạng | **PASS** | `curl` tới `http://openwrt.tail7e45a2.ts.net/cgi-bin/luci/` kết nối đúng `100.114.53.95`, HTTP 403 khi không có phiên đăng nhập; `tailscale ping` thành công. Chrome vẫn lỗi khi mở tên này; hiện tượng thuộc phía trình duyệt, chưa xác định extension hoặc chính sách cụ thể |
| Đổi mật khẩu root LuCI | **CHƯA THỰC HIỆN** | Đã mở trang **Hệ thống → Quản trị → Mật khẩu bộ định tuyến** trên tab LuCI hiện có và để trống hai ô cho chủ thiết bị tự nhập mật khẩu mới rồi LƯU; ảnh 18. Chưa coi là PASS trước khi kiểm tra lại |
| Ngoài LAN thực sự | **CHƯA KIỂM CHỨNG** | Windows vẫn dùng Ethernet trong LAN; chưa có phép thử qua điện thoại 4G/5G hoặc đường mạng độc lập |

![System Log hiển thị nội dung trong lần kiểm tra tiếp](reports/2026-10-11-clean-rebuild/screenshots/17-luci-system-log-recheck.png)

![Trang đổi mật khẩu đã chuẩn bị, ô nhập để trống](reports/2026-10-11-clean-rebuild/screenshots/18-luci-password-change-handoff.png)

### Theo dõi độ ổn định lúc 10:27–10:28 ngày 12/10/2026

| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| Tailscale sau 9 giờ 38 phút uptime | **PASS tại thời điểm kiểm tra** | `/etc/init.d/tailscale status` vẫn `running`, `tailscale ip -4` vẫn `100.114.53.95`; Windows CLI vẫn `100.85.51.71` và thấy router active |
| LuCI backend | **PASS tại thời điểm kiểm tra** | `rpcd` và `uhttpd` đều `running`; load 0.08/0.08/0.02; SSH bằng khóa qua tailnet tiếp tục thành công |
| WAN, định tuyến và firewall | **PASS tại thời điểm kiểm tra** | `fw4 check` thành công, WAN zone vẫn input REJECT/forward DROP, rule Tailscale chỉ nêu TCP 22/80; default route qua `10.2.28.1`, DNS `openwrt.org` thành công, ping `1.1.1.1` 2/2 |
| Đổi mật khẩu root | **CHƯA THỰC HIỆN** | `/etc/shadow` vẫn có mtime 23:55:49 ngày 11/10, trước lúc chuẩn bị trang đổi mật khẩu; chưa có bằng chứng chủ thiết bị đã LƯU mật khẩu mới. Cần chủ thiết bị tự nhập và lưu theo quy tắc Computer Use |
| Kiểm tra Chrome/LuCI tiếp theo | **TẠM THỜI KHÔNG KIỂM TRA ĐƯỢC** | Phiên Chrome từng có tab OpenWrt hiện không còn trong danh sách trình duyệt có thể điều khiển; không tạo tab LuCI mới theo yêu cầu một tab |
| Truy cập ngoài LAN | **CHƯA KIỂM CHỨNG** | Windows vẫn có Ethernet nối LAN; chưa có thiết bị ở mạng độc lập để thử |

Các dòng PASS ở đây là kiểm tra tại thời điểm nêu trên; không thay thế phép thử ngoài LAN thực sự. Không thao tác NAS/HDD.

### Khả năng kiểm thử ngoài LAN tại 10:28 ngày 12/10/2026

Máy Windows có Wi-Fi nhưng đang ngắt kết nối; Ethernet vẫn nhận `192.168.1.185` từ LAN OpenWrt. Có profile Wi-Fi đã lưu cho mạng khác, nhưng phiên PowerShell hiện không có quyền quản trị để vô hiệu hóa Ethernet hoặc ép tuyến kiểm thử. Chỉ nối thêm Wi-Fi trong khi Ethernet còn hoạt động sẽ không chứng minh gói Tailscale đi từ ngoài LAN. Vì vậy **chưa chạy phép thử ngoài LAN** và không đánh dấu DONE cho tiêu chí này. Cần điện thoại dùng dữ liệu di động có Tailscale hoặc một máy ở mạng độc lập, hoặc một phiên thử có thể tách Ethernet an toàn.

### Xác minh lại LuCI lúc 10:47 ngày 12/10/2026

Phiên LuCI cũ hiển thị thông báo **Phiên hết hạn** sau nhiều giờ. Chủ thiết bị cung cấp lại thông tin đăng nhập; đăng nhập trên đúng tab OpenWrt hiện có qua `http://100.114.53.95` thành công, và `logread` ghi `luci: accepted login` từ `100.85.51.71`. Hai ô đặt mật khẩu mới hiện để trống trên **Hệ thống → Quản trị → Mật khẩu bộ định tuyến**. Mật khẩu root **chưa đổi**: mtime `/etc/shadow` vẫn là 23:55:49 ngày 11/10. Không lưu mật khẩu trong báo cáo.

Thử lại tên `http://openwrt.tail7e45a2.ts.net/cgi-bin/luci/` ngay trên cùng tab Chrome vẫn trả `net::ERR_BLOCKED_BY_CLIENT`; trở về IP tailnet thì LuCI tải được. DNS và đường tailnet đã được kiểm chứng riêng ở trên, nên đây là lỗi phía client/trình duyệt chưa cô lập được thành phần chặn. Không có thay đổi firewall hoặc router trong lần thử này.

| Tiêu chí | Kết quả |
|---|---|
| Đăng nhập lại LuCI qua IP Tailscale sau khi phiên hết hạn | **PASS** |
| LuCI qua tên MagicDNS trong Chrome | **FAIL — `ERR_BLOCKED_BY_CLIENT`** |
| Mật khẩu root mạnh | **CHƯA THỰC HIỆN — chủ thiết bị cần tự nhập và lưu mật khẩu mới** |
| Truy cập từ mạng ngoài LAN | **CHƯA KIỂM CHỨNG** |

![LuCI đã đăng nhập lại, trang đổi mật khẩu với hai ô trống](reports/2026-10-11-clean-rebuild/screenshots/19-luci-reauth-password-page.png)

### Kiểm tra tiếp lúc 11:18 ngày 12/10/2026

Chủ thiết bị xác nhận sẽ tự đổi mật khẩu root sau; vì vậy mục này **hoãn theo yêu cầu**, chưa đạt PASS. Không thay mật khẩu bằng tác vụ tự động và không lưu mật khẩu đã cung cấp vào README/ảnh.

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Router chạy liên tục 10 giờ 29 phút | **PASS tại thời điểm kiểm tra** | Tailscale, `rpcd`, `uhttpd` đều `running`; load 0.11/0.04/0.01 |
| Firewall quản trị | **PASS tại thời điểm kiểm tra** | `fw4 check` đạt; WAN input REJECT/forward DROP; zone `tailscale0` input/forward REJECT, chỉ rule TCP 22/80 và ICMP echo cho quản trị |
| Windows → router qua tailnet | **PASS từ máy hiện tại** | Windows Tailscale `100.85.51.71`; `Test-NetConnection` TCP 22 và 80 đều thành công trên interface `Tailscale`; SSH bằng khóa theo tên MagicDNS thành công |
| MagicDNS hệ điều hành | **PASS** | Windows phân giải `openwrt.tail7e45a2.ts.net` ra `100.114.53.95` |
| LuCI theo FQDN MagicDNS trong Chrome | **FAIL — phía client** | FQDN vẫn `net::ERR_BLOCKED_BY_CLIENT`; Chrome profile đang có AdGuard và Urban VPN, nhưng chưa chứng minh tiện ích nào gây lỗi. Công cụ trình duyệt từ chối mở `chrome://extensions` do chính sách chỉ cho `http:`/`https:`; không tìm đường vòng và không tự tắt tiện ích. Tên ngắn `openwrt` được kiểm thử thành công ở phần tiếp theo |
| Mật khẩu root mạnh | **HOÃN THEO CHỦ THIẾT BỊ** | Trang LuCI đổi mật khẩu đã mở và để trống; chủ thiết bị sẽ tự đổi sau |
| Truy cập từ Internet ngoài LAN | **CHƯA KIỂM CHỨNG** | Phép thử trên Windows hiện tại vẫn dùng Ethernet cùng LAN; cần thiết bị/mạng độc lập |

Không thay đổi cấu hình router hay dữ liệu NAS/HDD trong lần kiểm tra này.

### LuCI qua tên MagicDNS ngắn lúc 11:20 ngày 12/10/2026

Windows `Resolve-DnsName openwrt -Type A` trả CNAME `openwrt.tail7e45a2.ts.net` và IP `100.114.53.95`. Trên **chính tab OpenWrt hiện có**, Chrome mở được `http://openwrt/cgi-bin/luci/`; đăng nhập thành công, Overview hiển thị model/firmware và **System Log tải nội dung**. `logread` trên router ghi phiên đăng nhập lúc 11:20:16 từ **`100.85.51.71`**, xác nhận đi qua tailnet của Windows chứ không phải địa chỉ LAN `192.168.1.185`. Sau phép thử, tab được đưa về trang đổi mật khẩu qua IP Tailscale để chủ thiết bị dùng sau.

| Tiêu chí | Kết quả |
|---|---|
| MagicDNS tên ngắn `openwrt` trên Windows | **PASS — phân giải về `100.114.53.95`** |
| LuCI Overview/System Log qua `http://openwrt` trên Chrome | **PASS từ máy Windows hiện tại** |
| LuCI qua FQDN `openwrt.tail7e45a2.ts.net` trên Chrome | **FAIL — vẫn bị `ERR_BLOCKED_BY_CLIENT`** |
| Truy cập từ mạng Internet ngoài LAN | **CHƯA KIỂM CHỨNG** |

![LuCI Overview qua tên MagicDNS ngắn](reports/2026-10-11-clean-rebuild/screenshots/20-luci-magicdns-shortname-overview.png)

![LuCI System Log qua tên MagicDNS ngắn](reports/2026-10-11-clean-rebuild/screenshots/21-luci-magicdns-shortname-syslog.png)

### Kiểm thử sau khi rút Ethernet lúc 11:24–11:27 ngày 12/10/2026

Chủ thiết bị đã rút dây LAN khỏi Windows. `Get-NetAdapter` xác nhận **Ethernet Disconnected**, Wi-Fi **Up** ở `192.168.0.104/24` qua gateway `192.168.0.1`; LAN OpenWrt là `192.168.1.0/24`. Windows còn địa chỉ/tuyến cũ gắn với adapter Ethernet đã ngắt, nhưng default route đang hoạt động qua Wi-Fi. Đây là phép thử **ngoài LAN OpenWrt**, không phải phép thử từ một địa điểm hoặc ISP khác. Router vẫn nối WAN `10.2.28.22/24` qua `10.2.28.1`.

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Kết nối Windows ngoài LAN OpenWrt | **PASS** | Ethernet `Disconnected`; Wi-Fi `192.168.0.104/24`, default gateway `192.168.0.1`, khác LAN router `192.168.1.0/24` |
| Đường Tailscale từ Wi-Fi tới router | **PASS** | Windows `100.85.51.71`; `tailscale ping` nhận pong qua DERP `hkg`; `tailscale status` hai phía ghi peer active qua relay `hkg`. Lệnh ping có exit code 1 vì chưa lập được kết nối trực tiếp sau 3 lần thử, nhưng các pong relay đều thành công |
| Cổng quản trị qua tailnet | **PASS** | `Test-NetConnection 100.114.53.95` với TCP 22 và 80 đều `True`, interface `Tailscale`, source `100.85.51.71` |
| Đường LAN trực tiếp từ Wi-Fi hiện tại | **KHÔNG TRUY CẬP ĐƯỢC** | `Test-NetConnection 192.168.1.1 -Port 80` trả `False`, interface `Wi-Fi`, source `192.168.0.104`; củng cố rằng phép thử LuCI thành công ở trên đi qua tailnet |
| Cổng quản trị trên IP WAN riêng từ Wi-Fi hiện tại | **KHÔNG TRUY CẬP ĐƯỢC** | `Test-NetConnection 10.2.28.22` tới TCP 22/80 đều `False` từ Wi-Fi `192.168.0.104`. Kết quả chỉ áp dụng cho mạng thử này; không thay thế việc kiểm tra rule firewall hoặc một phép quét từ Internet công cộng |
| SSH bằng khóa và host key đã xác minh | **PASS** | Đăng nhập SSH qua `100.114.53.95` và `openwrt.tail7e45a2.ts.net` thành công với `StrictHostKeyChecking=yes`; router trả uptime hơn 10 giờ, daemon Tailscale `running`, IP `100.114.53.95` |
| LuCI qua IP tailnet | **PASS** | Trên đúng tab OpenWrt hiện có, Overview và System Log tải nội dung, không kẹt `Đang tải…`; ảnh 22–23 |
| MagicDNS và LuCI tên ngắn | **PASS** | `Resolve-DnsName openwrt` và FQDN trả `100.114.53.95`; SSH qua FQDN thành công; LuCI Overview qua `http://openwrt` tải đầy đủ trên Wi-Fi ngoài LAN; ảnh 24 |
| Backend LuCI | **PASS tại thời điểm thử** | `/etc/init.d/rpcd status`, `/etc/init.d/uhttpd status` và `/etc/init.d/tailscale status` đều `running`; load lúc đầu `0.01, 0.18, 0.11`; RAM LuCI hiển thị còn khoảng 137 MiB có sẵn |
| Truy cập từ địa điểm/ISP khác | **CHƯA KIỂM CHỨNG** | Wi-Fi hiện tại là mạng khác LAN OpenWrt; chưa có phép thử ở một vị trí/ISP độc lập. Không suy rộng kết quả sang tình huống đó |
| Mật khẩu root mạnh | **CHƯA ĐẠT, HOÃN THEO CHỦ THIẾT BỊ** | Chưa đổi mật khẩu LuCI; SSH bằng mật khẩu đã tắt. Chủ thiết bị xác nhận sẽ tự đổi sau |

![LuCI Overview tải qua IP Tailscale sau khi rút Ethernet](reports/2026-10-11-clean-rebuild/screenshots/22-off-lan-luci-overview.jpg)

![LuCI System Log tải qua IP Tailscale sau khi rút Ethernet](reports/2026-10-11-clean-rebuild/screenshots/23-off-lan-luci-system-log.jpg)

![LuCI Overview qua tên MagicDNS ngắn trên Wi-Fi ngoài LAN](reports/2026-10-11-clean-rebuild/screenshots/24-off-lan-luci-magicdns-shortname.jpg)

Không sửa firewall, reboot lại hoặc thao tác ổ NAS/HDD trong phép thử này. Các kiểm chứng reboot, firewall và WAN ở các mục trước vẫn là trạng thái gần nhất của những hạng mục đó. Chrome vẫn chặn riêng FQDN MagicDNS với `ERR_BLOCKED_BY_CLIENT`; tên ngắn `openwrt`, SSH theo FQDN và IP tailnet đã hoạt động.

Lúc 11:28, sau phép thử, Windows vẫn dùng Wi-Fi, Ethernet `Disconnected`; router vẫn chạy Tailscale, `rpcd`, `uhttpd`, `fw4 check` đạt, IP Tailscale không đổi. `/etc/shadow` vẫn có mtime 23:55 ngày 11/10, nên **chưa có bằng chứng mật khẩu root đã được đổi**. Log gần nhất chỉ có cảnh báo khởi động Tailscale đã qua ở đầu uptime và các lần đăng nhập LuCI thành công; không có bằng chứng mới để xác định nguyên nhân gốc của hiện tượng LuCI từng treo. Không suy diễn từ các cảnh báo khởi động đó.

### Xác nhận quản trị qua một đường Internet khác lúc 11:32–11:34 ngày 12/10/2026

Theo yêu cầu tập trung vào vận hành ngoài LAN và hoãn đổi mật khẩu, kiểm tra lại khi Windows đã chuyển sang Wi-Fi `10.31.110.127/24`, gateway `10.31.110.104`; Ethernet vẫn `Disconnected`. Đây là mạng khác với cả LAN OpenWrt `192.168.1.0/24` và Wi-Fi `192.168.0.0/24` dùng trong phép thử trước. `tailscale netcheck` trên Windows và router đều phát hiện IPv4 công cộng, và hai địa chỉ này **khác nhau**; không ghi địa chỉ công cộng vào báo cáo. Điều đó xác nhận hai đầu dùng đường ra Internet khác nhau tại thời điểm thử, nhưng không đủ để khẳng định nhà mạng hoặc vị trí địa lý khác nhau.

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Đường mạng ngoài LAN | **PASS** | Windows Wi-Fi `10.31.110.127/24`, gateway `10.31.110.104`, Ethernet `Disconnected`; router LAN `192.168.1.0/24`, WAN `10.2.28.22/24` |
| Hai đầu có đường ra Internet khác nhau | **PASS** | `tailscale netcheck` trên Windows và router đều chạy thành công, IPv4 công cộng phát hiện được và khác nhau; không lưu giá trị IP công cộng |
| Tailscale Windows ↔ router | **PASS** | Windows `100.85.51.71`, router `100.114.53.95`; `tailscale ping` có 3 pong qua DERP `hkg`. Exit code 1 chỉ biểu thị không lập được đường trực tiếp sau 3 lần thử, không phải mất kết nối qua relay |
| Cổng quản trị tailnet | **PASS** | `Test-NetConnection 100.114.53.95` TCP 22/80 đều `True`, interface `Tailscale`, source `100.85.51.71` |
| SSH thật qua MagicDNS | **PASS** | SSH dùng khóa và host key đã xác minh tới `openwrt.tail7e45a2.ts.net` thành công; router trả uptime hơn 10 giờ 43 phút và peer Windows active qua relay `hkg` |
| LuCI qua IP tailnet | **PASS** | Cùng tab OpenWrt hiện có tải đầy đủ Overview và System Log; không kẹt ở `Đang tải…`; ảnh 25–26 |
| LuCI qua tên ngắn MagicDNS | **PASS** | `Resolve-DnsName` trả `100.114.53.95`; cùng tab mở `http://openwrt/cgi-bin/luci/` và hiển thị model/firmware/router uptime |
| Dịch vụ và firewall sau reboot | **PASS tại thời điểm này** | `/etc/init.d/tailscale`, `rpcd`, `uhttpd` đều `running`; `fw4 check` đạt; router vẫn giữ IP Tailscale `100.114.53.95` |
| FQDN MagicDNS trong Chrome | **FAIL phía client** | Trình duyệt còn trả `ERR_BLOCKED_BY_CLIENT` cho FQDN; tên ngắn và SSH theo FQDN hoạt động. Chưa xác định được thành phần chặn |
| Mật khẩu root mạnh | **HOÃN THEO CHỦ THIẾT BỊ** | Chưa đổi; chủ thiết bị yêu cầu để sau. SSH root bằng mật khẩu vẫn tắt |

![LuCI Overview qua Tailscale trên Wi-Fi ngoài LAN](reports/2026-10-11-clean-rebuild/screenshots/25-luci-over-separate-wifi.jpg)

![LuCI System Log qua Tailscale trên Wi-Fi ngoài LAN](reports/2026-10-11-clean-rebuild/screenshots/26-luci-system-log-over-separate-wifi.jpg)

**Kết luận phạm vi này:** quản trị OpenWrt bằng Tailscale qua một đường Internet khác đã được kiểm chứng thực tế bằng SSH và LuCI. Không mở cổng quản trị ra WAN công cộng, không thay đổi NAS/HDD. Phần đổi mật khẩu và lỗi Chrome với FQDN được ghi riêng, không làm giảm kết quả PASS của IP tailnet và tên ngắn MagicDNS.

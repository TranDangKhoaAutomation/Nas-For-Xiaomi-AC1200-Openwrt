# Truy cập NAS từ xa trên Windows và Android

Hướng dẫn cập nhật ngày **30/10/2026**. Máy khách dùng Tailscale để đến router, sau đó dùng SMB để mở dữ liệu. Router và ổ NAS cần được bật; máy Windows ở nhà không cần chạy thường trực.

Hướng dẫn cũng có ngay trong LuCI tại **Các dịch vụ → Hướng dẫn kết nối**: [mở qua Tailscale](http://100.114.53.95/cgi-bin/luci/admin/services/nas-connect) hoặc [mở trong mạng nhà](http://192.168.1.1/cgi-bin/luci/admin/services/nas-connect). Trang lấy IP và danh sách share từ cấu hình router, cho chọn LAN/Tailscale, xem Windows/Android, sao chép đường dẫn và làm mới thông tin; đồng thời cảnh báo share chưa gắn hoặc chỉ đọc. Từ trang **Ổ đĩa** cũng có liên kết tới hướng dẫn.

## Địa chỉ và trạng thái hiện tại

| Mục | Giá trị |
|---|---|
| Router trong Tailscale | `100.114.53.95`, tên thiết bị `openwrt` |
| Trang quản lý ổ đĩa từ xa | [Hệ thống → Ổ đĩa](http://100.114.53.95/cgi-bin/luci/admin/system/disks) |
| Share BitLocker 100 GiB | `\\100.114.53.95\BITLOCKER` — hiện **đọc/ghi**, đã kiểm tra SMB ngày 30/10 |
| Share NTFS khoảng 831,5 GiB | `\\100.114.53.95\DANGKHOA` — đã hết dirty sau CHKDSK trên Windows, hiện **đọc/ghi** |
| Tài khoản SMB | `nas`; mật khẩu nhập trực tiếp trên thiết bị, không ghi trong repo |
| Cổng SMB | TCP `445` trong tailnet |

Đây là địa chỉ của router tham chiếu. Sau reset/đăng ký lại Tailscale hoặc đổi router, lấy IPv4 mới trong danh sách thiết bị Tailscale hoặc chạy `tailscale ip -4` trên router, rồi thay địa chỉ trong các ví dụ. Khi đang ở xa, dùng IP Tailscale thay cho IP LAN `192.168.1.1`.

## 1. Kết nối Tailscale

1. Cài Tailscale trên máy Windows hoặc điện thoại Android từ [nguồn chính thức](https://tailscale.com/download).
2. Đăng nhập vào tailnet đã được cấp quyền truy cập router. Nếu dùng tài khoản khác, quản trị tailnet phải mời/chia sẻ thiết bị và cho phép quyền cần thiết.
3. Bật kết nối Tailscale và kiểm tra router `openwrt` đang trực tuyến.
4. Giữ Tailscale kết nối trong lúc dùng NAS.

Router đã chạy Tailscale trực tiếp, nên truy cập IP của router không cần bật exit node hoặc quảng bá cả mạng LAN. Trên Android chỉ có một VPN hoạt động tại một thời điểm; VPN khác có thể ngắt Tailscale. [Tài liệu Android](https://tailscale.com/docs/install/android), [Tailscale và VPN khác](https://tailscale.com/docs/reference/faq/other-vpns).

## 2. Windows: mở dữ liệu và map thành ổ trong This PC

### Mở nhanh

Trong **Các dịch vụ → Hướng dẫn kết nối**, chọn **Windows**, kiểu kết nối và share. Nút **Mở thư mục NAS** gọi File Explorer qua [tiện ích Windows](../software/windows-open-nas/README.md). Cài tiện ích một lần trên mỗi máy và nhập IP router được phép; sau đó có thể mở bằng nút này thay vì chép đường dẫn. Nút tải tiện ích nằm cạnh nút mở. Cách nhập đường dẫn thủ công bên dưới vẫn dùng được mà không cần tiện ích.

1. Bật Tailscale.
2. Mở **File Explorer / Trình khám phá tệp**.
3. Bấm thanh địa chỉ, nhập:

   ```text
   \\100.114.53.95\BITLOCKER
   ```

4. Khi được hỏi tài khoản, chọn **More choices / Lựa chọn khác → Use a different account / Dùng tài khoản khác** nếu cần; nhập user `nas` và mật khẩu SMB.
5. Sau khi mở được, thao tác tệp theo trạng thái thực tế của share. Ngày 30/10 đã thử tạo, đọc lại và xóa tệp trên cả BITLOCKER và DANGKHOA; nếu trang Ổ đĩa báo chỉ đọc thì không thể ghi.

### Map ổ bền vững

1. Trong **This PC / PC này**, chọn **Map network drive / Ánh xạ ổ đĩa mạng**. Trên một số bản Windows 11, mục này nằm trong nút `…`.
2. Chọn chữ cái chưa sử dụng, ví dụ `Q:`.
3. Folder / Thư mục: `\\100.114.53.95\BITLOCKER`.
4. Chọn **Reconnect at sign-in / Kết nối lại khi đăng nhập** và **Connect using different credentials / Kết nối bằng thông tin đăng nhập khác** nếu cần.
5. Hoàn tất và nhập user `nas` cùng mật khẩu SMB.

Cách tương đương bằng Terminal; dấu `*` yêu cầu nhập mật khẩu tại prompt, không đưa mật khẩu vào lệnh:

```powershell
net use Q: \\100.114.53.95\BITLOCKER * /user:nas /persistent:yes
```

Đổi `Q:` nếu chữ cái này đã dùng cho ổ khác. Khi đăng nhập Windows mà Tailscale chưa sẵn sàng, ổ mạng có thể hiện dấu đỏ; bật Tailscale rồi mở lại đường dẫn UNC để nối lại. [Hướng dẫn ánh xạ ổ của Microsoft](https://support.microsoft.com/en-us/windows/experience/connectivity-networking/file-sharing-over-a-network-in-windows).

### Kiểm tra kết nối

```powershell
tailscale status
Test-NetConnection 100.114.53.95 -Port 445
Test-Path '\\100.114.53.95\BITLOCKER'
```

TCP phải thành công trước khi xử lý tài khoản SMB. `Test-Path=True` chứng minh share mở được bằng thông tin đăng nhập hiện có; không chứng minh share cho phép ghi.

## 3. Android: thêm kết nối SMB trong ứng dụng quản lý tệp

Trong tab Android của trang hướng dẫn, nút **Mở thư mục NAS** dùng liên kết `smb://` theo IP và share đang chọn. Chỉ những ứng dụng có đăng ký nhận liên kết này mới mở trực tiếp; nếu không mở được, thêm kết nối thủ công theo các bước bên dưới.

Trên Android, NAS hiện thành một **kết nối mạng trong ứng dụng quản lý tệp**. Chọn ứng dụng hỗ trợ SMB2/SMB3 và cho nhập tên share, chẳng hạn các ứng dụng được nêu trong [hướng dẫn NAS từ xa của Tailscale](https://tailscale.com/docs/use-cases/personal-or-at-home-use/access-nas-media-file-servers?tab=android).

1. Mở Tailscale, kết nối đúng tailnet và xác nhận router trực tuyến.
2. Mở ứng dụng quản lý tệp → **Network / Mạng → Add connection / Thêm kết nối → SMB hoặc Windows share**. Tên menu phụ thuộc ứng dụng.
3. Điền:

   | Trường | Giá trị |
   |---|---|
   | Server / Host / Địa chỉ | `100.114.53.95` |
   | Port / Cổng | `445` |
   | Share / Thư mục chia sẻ | `BITLOCKER` |
   | Username / Tài khoản | `nas` |
   | Password / Mật khẩu | Mật khẩu SMB của user `nas` |
   | Domain / Miền | Để trống, trừ khi ứng dụng yêu cầu cấu hình khác |
   | Phiên bản giao thức | SMB2 hoặc SMB3 |

4. Lưu kết nối rồi mở `BITLOCKER`. Nếu ứng dụng liệt kê share sau khi đăng nhập, chọn `BITLOCKER` trong danh sách.
5. Để dùng khi không có mạng, chép tệp cần thiết về bộ nhớ điện thoại. Truy cập trực tiếp trên NAS cần Internet và Tailscale đang kết nối.

Các bản Khoa-NAS Android cũ trong repo chỉ có danh sách `NAS1/NAS2/PRIVATE` và địa chỉ cũ. Không dùng mặc định của bản đó để suy ra share hiện tại; hướng dẫn này dùng một SMB client cho phép nhập `BITLOCKER`.

### Android không bật VPN Tailscale riêng

Trong mạng nhà, dùng IP LAN của router và không cần Tailscale. Khi ở ngoài mạng nhà, app SMB hiện có vẫn cần đường kết nối tới NAS; chỉ đổi nút hay IP không thay thế được đường kết nối đó.

Một hướng phát triển là tích hợp kết nối Tailscale riêng bên trong app bằng [tsnet](https://tailscale.com/docs/features/tsnet) hoặc [libtailscale](https://github.com/tailscale/libtailscale), dùng TCP/IP trong tiến trình ứng dụng. Đây là đề xuất kiến trúc dựa trên khả năng nhúng của thư viện, chưa phải tính năng của APK hiện tại và chưa kiểm thử tích hợp Android. Cần thêm cầu nối native, luồng đăng nhập tailnet, lưu trạng thái riêng trong app và kiểm tra vòng đời/kết nối nền. Không nhúng auth key dùng chung vào APK. Không mở SMB 445 ra Internet để thay thế.

## 4. Mở khóa hoặc quản lý ổ từ xa bằng LuCI

Khi Tailscale đang kết nối, mở:

[http://100.114.53.95/cgi-bin/luci/admin/system/disks](http://100.114.53.95/cgi-bin/luci/admin/system/disks)

1. Đăng nhập tài khoản quản trị router.
2. Trong **Hệ thống → Ổ đĩa**, tìm đúng phân vùng theo nhãn, dung lượng và UUID.
3. Bấm **Quản lý**. Với BitLocker, nhập mật khẩu phân vùng nếu chưa có khóa đã lưu.
4. Bật **Tự mở khóa và gắn sau khởi động** nếu muốn lưu mật khẩu đã xác minh trên router, rồi bấm **Lưu và mở khóa**.
5. Đợi trạng thái **Đã gắn · chỉ đọc** hoặc **Đã gắn · đọc/ghi** trước khi mở share SMB.

Mỗi phân vùng có cấu hình riêng theo UUID. Khi thay ổ, quét lại và thiết lập ổ mới; cấu hình cũ không áp dụng theo tên `sda`/`sdb`.

| Thông tin đăng nhập | Dùng ở đâu |
|---|---|
| Tài khoản Tailscale | Đưa thiết bị vào tailnet được phép |
| Tài khoản quản trị router | Mở LuCI, chỉnh cấu hình và quản lý ổ |
| Mật khẩu BitLocker | Mở khóa phân vùng mã hóa trên router |
| User `nas` + mật khẩu SMB | Đọc/ghi share trong File Explorer hoặc SMB client Android |

Các loại mật khẩu này độc lập. Khóa BitLocker lưu trên router chỉ root được đọc; người chiếm được quyền root hoặc flash/backup chứa khóa có thể lấy mật khẩu. Giữ recovery key riêng.

## 5. Khi không truy cập được

| Hiện tượng | Kiểm tra/xử lý |
|---|---|
| Không tới được router | Tailscale ở cả hai đầu, đúng tailnet/quyền, router trực tuyến, Internet hoạt động |
| Windows TCP 445 thất bại | ACL/grants tailnet, rule firewall Tailscale và KSMBD có lắng nghe `tailscale0` |
| Hỏi mật khẩu nhiều lần | Dùng mật khẩu SMB của `nas`, không dùng mật khẩu root hoặc BitLocker |
| Windows lỗi 1219 | Chạy `net use` để xác định kết nối trùng tới đúng router; ngắt riêng map NAS liên quan rồi nối lại. Không xóa toàn bộ map đang dùng |
| Thấy thư mục rỗng/share không dùng được | Kiểm tra phân vùng đã mount thật trong trang Ổ đĩa; sự tồn tại của tên share không chứng minh dữ liệu đã được gắn |
| `DANGKHOA` chưa mở được | Kiểm tra trạng thái gắn. Ngày 30/10 đã hết dirty và ghi được; nếu dirty tái xuất hiện, sao lưu và kiểm tra NTFS trên ổ cắm trực tiếp vào Windows |
| `BITLOCKER` không ghi được | Kiểm tra trạng thái mount thực tế và quyền share. Ngày 30/10 đã chuyển RW thành công sau CHKDSK; manager không force dirty NTFS |
| Android mất kết nối khi bật VPN khác | Android chỉ cho một VPN hoạt động; chọn Tailscale khi cần NAS |
| IP không còn đúng sau reset | Lấy IP mới từ Tailscale, cập nhật kết nối Windows/Android và URL LuCI |

Không mở hoặc port-forward TCP 445 từ Internet công cộng. Dùng đường tailnet đã xác thực; WAN trên hệ thống tham chiếu vẫn từ chối kết nối vào.

## Phạm vi đã kiểm chứng ngày 29/10/2026

- Router Tailscale `100.114.53.95` chạy; firewall cho quản trị/SMB từ zone Tailscale và không mở SMB ra WAN.
- KSMBD template có `tailscale0`; Windows báo TCP 445 thành công qua interface **Tailscale** và `Test-Path \\100.114.53.95\BITLOCKER=True`.
- BitLocker tự mở, mount chỉ đọc và SMB đọc được sau reboot thật, không chạy unlock thủ công.
- Lần kiểm tra này chưa đưa điện thoại ra 4G/5G hoặc thử Android thực tế. Các bước Android là hướng dẫn cấu hình, không phải kết quả đã thử trên điện thoại.

Để tự kiểm thử từ xa độc lập: trên Android tắt Wi-Fi, dùng 4G/5G, bật Tailscale rồi mở `BITLOCKER`; trên Windows dùng mạng khác LAN router. Khi share đang chỉ đọc, chỉ thử mở/đọc tệp.

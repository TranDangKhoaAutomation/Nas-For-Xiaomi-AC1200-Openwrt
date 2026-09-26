# LƯU Ý SNAPSHOT

Snapshot lịch sử 2026-09-25; trạng thái mới hơn xem README/docs.

# BÁO CÁO HOÀN TẤT ROUTER NAS
Ngày hoàn tất: 2026-09-25

## 1. Trạng thái cuối

Router:
- Xiaomi Mi Router 3G
- OpenWrt 25.12.5
- Kernel 6.12.94
- Tailscale IPv4: <TAILSCALE_IP>
- SMB server: KSMBD
- SMB chỉ được firewall cho phép từ zone Tailscale; TCP 445 từ WAN bị REJECT.
- KSMBD standalone không tự khởi động ở boot. Dịch vụ nas-storage quản lý thời điểm KSMBD được bật.

HDD:
- HGST HTS721010A9E630, 1 TB, 7200 RPM
- Partition table: MBR/DOS

## 2. Sơ đồ phân vùng và share

| Vùng | Thiết bị | Kích thước | Filesystem | Mount | SMB share | Trạng thái |
|---|---|---:|---|---|---|---|
| NAS1 | /dev/sda1 | ~831.5 GiB | NTFS | /mnt/nas | NAS1 | RW |
| NAS2 | /dev/sda2 | ~50 GiB | NTFS | /mnt/nas2 | NAS2 | RW |
| PRIVATE | /dev/sda3 -> /dev/mapper/private | ~50 GiB | VeraCrypt + NTFS | /mnt/private | PRIVATE | RW khi đã unlock |

Stable identities:
- NAS1 UUID: 01DC8764756E6240
- NAS2 UUID: 78F6F2BBF6F278A8
- PRIVATE được xác định là partition 3 trên cùng physical disk chứa đúng hai UUID trên.

## 3. Truy cập từ xa

Dùng Tailscale trên thiết bị client, sau đó truy cập:

- \\<TAILSCALE_IP>\NAS1
- \\<TAILSCALE_IP>\NAS2
- \\<TAILSCALE_IP>\PRIVATE

Đã kiểm tra TCP 445 qua địa chỉ Tailscale: PASS.

Đã kiểm tra liệt kê thư mục qua cả ba UNC path: PASS.

Đã kiểm tra tạo -> đọc lại -> xóa file nhỏ qua SMB/Tailscale:
- NAS1: PASS
- NAS2: PASS
- PRIVATE: PASS

Lưu ý: phép thử hiện tại được thực hiện từ máy Windows hiện tại bằng địa chỉ Tailscale. Nó xác nhận đường SMB qua tailnet; không phải phép thử từ một ISP/vị trí địa lý khác.

## 4. VeraCrypt PRIVATE

Thiết bị raw:
- /dev/sda3

Mapper:
- /dev/mapper/private

cryptsetup nhận dạng:
- type: TCRYPT
- cipher: aes-xts-plain64
- cryptsetup keysize report: 512 bits
- mode: read/write

Filesystem bên trong đã xác nhận bằng boot sector NTFS.

Passphrase VeraCrypt:
- KHÔNG lưu trong router.
- KHÔNG lưu trong script.
- KHÔNG ghi vào báo cáo.
- Sau reboot hoặc sau khi lock, người dùng nhập trực tiếp vào cryptsetup qua terminal SSH.

### Unlock PRIVATE

Từ Windows:

    ssh -t -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager unlock-private"

Hoặc chạy:

    D:\Bao-Cao-Router-Nas\Unlock-PRIVATE.cmd

Sau khi unlock thành công, manager tự:
1. mở /dev/sda3 thành /dev/mapper/private;
2. mount NTFS vào /mnt/private;
3. tạo/khôi phục share PRIVATE;
4. reload KSMBD khi cần.

### Lock PRIVATE

    ssh -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager lock-private"

Manager sẽ dừng KSMBD trong thời gian ngắn, sync, unmount PRIVATE, đóng mapper và gỡ share PRIVATE.

## 5. Multi-volume storage manager

File đang chạy:

    /usr/sbin/nas-storage-manager

Backup trước khi sửa:

    /usr/sbin/nas-storage-manager.bak-20260925

Dịch vụ:

    /etc/init.d/nas-storage

Boot:
- S97nas-storage
- K04nas-storage

Watchdog:
- procd chạy /usr/sbin/nas-storage-manager watch
- chu kỳ reconcile: khoảng 5 giây
- procd respawn nếu process chết.

Chức năng:
- NAS1/NAS2 được tìm bằng UUID, không phụ thuộc cố định vào sda/sdb.
- PRIVATE chỉ chọn partition 3 của đúng physical disk chứa cả NAS1_UUID và NAS2_UUID.
- Không format.
- Không tự repair filesystem.
- Không force dirty NTFS RW.
- Nếu RW mount thất bại thì fallback RO.
- Nếu disk/remove/reset xảy ra thì unmount/cleanup share và mapper.
- Nếu PRIVATE chưa unlock thì share PRIVATE bị xóa khỏi KSMBD.
- Khi mapper PRIVATE xuất hiện thì manager tự mount và tạo lại share.
- Manager chỉ bật KSMBD khi có storage thật đang mount, tránh expose thư mục rỗng trên flash router.

Watchdog self-heal đã được test bằng cách xóa tạm share NAS2; manager tự tạo lại trong khoảng 7 giây và UNC path hoạt động lại: PASS.

## 6. NAS1 dirty flag

NAS1 từng bị NTFS dirty sau chuỗi USB reset.

Đã thực hiện:
1. ntfsfix -n /dev/sda1
   - MFT/MFTMirr: OK
   - alternate boot sector: OK
   - NTFS 3.1
   - no-action check: PASS
2. stop KSMBD + sync + unmount NAS1
3. ntfsfix -d /dev/sda1
4. mount lại bằng ntfs3 RW: PASS
5. SMB/Tailscale RW test: PASS

Nếu HDD bị rút nóng hoặc USB reset lại và volume trở thành dirty, manager sẽ ưu tiên RO thay vì force RW. Khi đó nên chạy Windows chkdsk /f trước khi tiếp tục ghi dữ liệu.

## 7. Firewall và Tailscale

Rule cho SMB từ Tailscale:
- source: tailscale
- protocol: TCP
- destination port: 445
- target: ACCEPT

Rule WAN:
- source: wan
- protocol: TCP
- destination port: 445
- target: REJECT

Không port-forward TCP 445 trực tiếp ra Internet.

KSMBD interface hiện gồm LAN + Tailscale, vì vậy có thể dùng cả local LAN và tailnet. Đường truy cập từ xa được khuyến nghị là Tailscale.

## 8. USB/HDD: cảnh báo phần cứng còn tồn tại

Trong cùng phiên boot đã từng ghi nhận:
- repeated SuperSpeed USB reset;
- I/O error trên /dev/sda;
- Buffer I/O error trên sda2;
- device offlined;
- USB power cycle;
- reconnect bằng usb-storage.

Kernel từng in "Maybe the USB cable is bad?", nhưng đây là thông báo chung và không chứng minh cáp hỏng.

Windows trước đó cũng từng ghi UASPStor reset / disk I/O retry, nên cần tiếp tục theo dõi cả:
- nguồn cấp cho HDD 2.5" 7200 RPM;
- USB-SATA bridge RTL9201;
- cổng USB/controller;
- cáp;
- bản thân HDD.

Sau các bài test RW nhỏ cuối cùng không xuất hiện chuỗi USB reset/I/O error mới.

Không nên benchmark/write nặng kéo dài cho tới khi độ ổn định đường USB được xác nhận lâu hơn. Nếu reset quay lại, ưu tiên hub USB có nguồn riêng hoặc bridge/nguồn khác.

## 9. SMART / filesystem baseline

SMART qua USB-SATA bridge:
- attribute-based overall check: PASSED
- bridge trả incomplete ATA output registers cho một số status

Các lần kiểm tra trước:
- Reallocated sectors: 0
- Current pending: 0
- Offline uncorrectable: 0
- HDD có số giờ hoạt động và load-cycle cao; cần backup dữ liệu quan trọng.

Windows CHKDSK trước đó:
- filesystem scan: không tìm lỗi
- 0 KB bad sectors

Các kết quả trên không thay thế backup và không loại trừ lỗi USB/power/bridge.

## 10. Lệnh vận hành

Status:

    ssh -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager status"

Reconcile thủ công:

    ssh -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager reconcile"

Unlock PRIVATE:

    ssh -t -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager unlock-private"

Lock PRIVATE:

    ssh -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager lock-private"

Safe eject toàn bộ HDD:

    ssh -F "C:\Users\Admin\OneDrive\Documents\Codex\openwrt_ssh_config" owrt "/usr/sbin/nas-storage-manager eject"

Menu Windows:

    D:\Bao-Cao-Router-Nas\NAS-Remote-Menu.cmd

## 11. Hành vi sau reboot

Sau router reboot:
1. nas-storage khởi động ở S97.
2. NAS1 và NAS2 tự tìm theo UUID và auto-mount.
3. KSMBD chỉ khởi động sau khi có volume thật.
4. PRIVATE ở trạng thái LOCKED vì password không được lưu.
5. Share PRIVATE không được expose khi mapper chưa active.
6. Chạy Unlock-PRIVATE.cmd và nhập passphrase để PRIVATE xuất hiện lại.

Đây là hành vi cố ý để đảm bảo vùng mã hóa không tự mở khi router bị lấy hoặc reboot.

## 12. Rollback

Nếu cần quay lại manager cũ trên router:

    cp /usr/sbin/nas-storage-manager.bak-20260925 /usr/sbin/nas-storage-manager
    chmod 755 /usr/sbin/nas-storage-manager

Sau đó restart/reconcile phù hợp. Không xóa backup cho tới khi hệ thống đã chạy ổn định đủ lâu.

## 13. File đã lưu tại D:\Bao-Cao-Router-Nas

Các file chính:
- Bao-Cao-Hoan-Tat-Router-NAS.md
- nas-storage-manager.final
- nas-storage-manager.current
- nas-storage.init.current
- 95-nas-storage.current
- ksmbd.final
- firewall.final
- NAS-Remote-Menu.cmd
- Unlock-PRIVATE.cmd
- NAS-Status.cmd
- 01_CHKDSK_F_REPAIR.txt

Các file helper thử nghiệm VeraCrypt cũ có thể được dọn sau khi xác nhận không còn cần.

---
Không có password, password hash, private key hoặc VeraCrypt secret nào được ghi trong báo cáo này.

## 14. Hướng dẫn truy cập từ một máy Windows mới

### 14.1. Điều kiện

Máy Windows cần:
- Có Internet.
- Cài Tailscale.
- Đăng nhập đúng tailnet đang chứa router OpenWrt.
- Có thể route tới địa chỉ Tailscale của router: <TAILSCALE_IP>.

Không cần port-forward SMB trên modem/router Internet.

### 14.2. Kiểm tra Tailscale

Mở PowerShell:

    ping <TAILSCALE_IP>

Sau đó kiểm tra SMB:

    Test-NetConnection <TAILSCALE_IP> -Port 445

Kết quả mong đợi:

    TcpTestSucceeded : True

Nếu ping không trả lời nhưng TCP 445 vẫn True thì SMB vẫn có thể hoạt động; ACL/firewall có thể chặn ICMP.

### 14.3. Mở share trực tiếp

Nhấn Win + R và nhập một trong các đường dẫn:

    \\<TAILSCALE_IP>\NAS1
    \\<TAILSCALE_IP>\NAS2
    \\<TAILSCALE_IP>\PRIVATE

Tài khoản SMB hiện dùng:

    nas

Password SMB không được ghi trong báo cáo này.

### 14.4. Map thành ổ đĩa Windows

File Explorer -> This PC -> Map network drive.

Ví dụ:
- N: -> \\<TAILSCALE_IP>\NAS1
- M: -> \\<TAILSCALE_IP>\NAS2
- P: -> \\<TAILSCALE_IP>\PRIVATE

Có thể chọn "Reconnect at sign-in".

PRIVATE chỉ map/mở được khi VeraCrypt đã unlock trên router.

### 14.5. Lỗi Windows 1219 / nhiều credential

Windows thường không cho dùng nhiều bộ credential khác nhau đồng thời tới cùng một server/IP.

Nếu gặp:

    System error 1219

Xem session hiện tại:

    net use

Ngắt session tới router:

    net use \\<TAILSCALE_IP>\* /delete

Hoặc ngắt toàn bộ SMB session nếu chấp nhận:

    net use * /delete

Sau đó kết nối lại bằng credential đúng.

Không ghi password trực tiếp vào file BAT/CMD hoặc command history.

## 15. Hướng dẫn truy cập từ Android

Điện thoại Android cần:
1. Cài và đăng nhập Tailscale vào cùng tailnet.
2. Dùng file manager có hỗ trợ SMB2/SMB3.
3. Tạo kết nối SMB tới:

    Host/IP: <TAILSCALE_IP>
    Port: 445
    Username: nas

Share:
- NAS1
- NAS2
- PRIVATE

Password SMB nhập trực tiếp trong ứng dụng. Không dùng SMB1.

PRIVATE chỉ truy cập được sau khi đã unlock VeraCrypt trên router.

## 16. Quy trình sử dụng hằng ngày

### Bình thường

1. Router bật.
2. HDD cắm vào router.
3. NAS1/NAS2 được manager tự nhận theo UUID và mount.
4. Tailscale chạy.
5. Truy cập NAS1/NAS2 qua <TAILSCALE_IP>.

### Khi cần PRIVATE

Chạy:

    D:\Bao-Cao-Router-Nas\Unlock-PRIVATE.cmd

Nhập passphrase VeraCrypt khi được hỏi.

Sau khi lệnh hoàn tất, mở:

    \\<TAILSCALE_IP>\PRIVATE

### Khi không cần PRIVATE nữa

Chạy từ SSH:

    /usr/sbin/nas-storage-manager lock-private

Hoặc dùng:

    D:\Bao-Cao-Router-Nas\NAS-Remote-Menu.cmd

Chọn Lock PRIVATE.

### Trước khi rút HDD

Không rút nóng.

Chạy:

    /usr/sbin/nas-storage-manager eject

Hoặc chọn Safe eject HDD trong NAS-Remote-Menu.cmd.

Chỉ rút HDD sau khi manager báo các volume đã unmount.

## 17. Xử lý lỗi thường gặp

### 17.1. Không mở được NAS1/NAS2/PRIVATE

Trên Windows:

    Test-NetConnection <TAILSCALE_IP> -Port 445

Nếu False:
- Kiểm tra Tailscale trên client.
- Kiểm tra router có online trong tailnet.
- Kiểm tra firewall Tailscale.
- SSH vào router và chạy:

    /usr/sbin/nas-storage-manager status

### 17.2. NAS1 hoặc NAS2 không xuất hiện

Chạy:

    /usr/sbin/nas-storage-manager reconcile
    /usr/sbin/nas-storage-manager status

Kiểm tra:

    block info

Manager nhận NAS1/NAS2 theo UUID; nếu UUID thay đổi do format/repartition thì phải cập nhật manager.

### 17.3. PRIVATE không xuất hiện

Kiểm tra:

    cryptsetup status private

Nếu inactive:

    /usr/sbin/nas-storage-manager unlock-private

Nếu active nhưng chưa mount:

    /usr/sbin/nas-storage-manager reconcile

Kiểm tra:

    mount

Phải thấy:

    /dev/mapper/private on /mnt/private

Không chạy cryptsetup open nhiều lần đồng thời.

### 17.4. Unlock PRIVATE rất chậm

MT7621 là CPU MIPS tương đối yếu.

PBKDF2-SHA512 của VeraCrypt có thể mất khá lâu khi derive key. Trong lúc đó cryptsetup có thể dùng CPU đáng kể.

Sau khi unlock xong, CPU phải giảm về gần idle khi không truyền dữ liệu.

Không bấm/chạy unlock nhiều lần chỉ vì chưa thấy kết quả ngay.

### 17.5. NAS bị Read-Only

Manager cố ý fallback sang RO nếu NTFS không mount RW an toàn.

Kiểm tra:

    /usr/sbin/nas-storage-manager status
    dmesg | tail -n 100

Nếu NTFS dirty:
- Tốt nhất đưa HDD sang Windows.
- Chạy chkdsk /f đúng volume.
- Eject an toàn.
- Cắm lại router.

Không dùng force mount RW khi filesystem đang dirty nếu dữ liệu quan trọng.

### 17.6. USB reset / I/O error

Dấu hiệu:

    reset SuperSpeed USB device
    I/O error, dev sda
    Buffer I/O error
    Device offlined
    attempt power cycle

Việc cần làm:
1. Dừng copy/benchmark nặng.
2. Không rút HDD khi đang có I/O.
3. Safe eject nếu hệ thống còn phản hồi.
4. Kiểm tra nguồn USB/bridge/cổng/cáp/HDD.
5. Nếu lỗi lặp lại, ưu tiên hub USB có nguồn riêng hoặc USB-SATA bridge khác.
6. Kiểm tra SMART và filesystem trước khi tiếp tục dùng dữ liệu quan trọng.

### 17.7. Windows thấy "Invalid Signature" hoặc share biến mất ngắn hạn

KSMBD có thể restart trong lúc manager cập nhật share.

Đợi khoảng 5–10 giây rồi thử lại.

Nếu vẫn lỗi:

    net use \\<TAILSCALE_IP>\* /delete

Sau đó mở lại share.

## 18. Khôi phục sau reboot router

Sau reboot:
- NAS1/NAS2 tự mount.
- PRIVATE vẫn LOCKED.
- KSMBD được manager bật khi storage sẵn sàng.
- Tailscale cần online để truy cập từ xa.

Kiểm tra:

    /usr/sbin/nas-storage-manager status
    tailscale ip -4

Nếu NAS1/NAS2 chưa xuất hiện, chờ khoảng 10 giây rồi:

    /usr/sbin/nas-storage-manager reconcile

Sau đó unlock PRIVATE thủ công nếu cần.

## 19. Khôi phục sau reset/flash lại OpenWrt

Sau khi cài lại firmware OpenWrt, cần khôi phục tối thiểu:

1. SSH key/config quản trị.
2. Tailscale và cấu hình tailnet.
3. cryptsetup cùng dm-crypt kernel support.
4. ntfs3/support package cần thiết.
5. KSMBD + SMB user.
6. Firewall:
   - cho TCP 445 từ Tailscale;
   - chặn TCP 445 từ WAN.
7. Copy lại:

    /usr/sbin/nas-storage-manager

8. Copy/khôi phục:

    /etc/init.d/nas-storage
    /etc/hotplug.d/block/95-nas-storage
    /etc/config/ksmbd

9. Đặt quyền:

    chmod 755 /usr/sbin/nas-storage-manager
    chmod 755 /etc/init.d/nas-storage

10. Enable manager:

    /etc/init.d/nas-storage enable
    /etc/init.d/nas-storage start

11. Kiểm tra:

    /usr/sbin/nas-storage-manager status

Không cần và không nên lưu VeraCrypt passphrase vào image backup/router config.

## 20. Các file cần giữ để phục hồi

Trong:

    D:\Bao-Cao-Router-Nas

Giữ tối thiểu:
- Bao-Cao-Hoan-Tat-Router-NAS.md
- nas-storage-manager.final
- nas-storage.init.current
- 95-nas-storage.current
- ksmbd.final
- firewall.final
- NAS-Remote-Menu.cmd
- Unlock-PRIVATE.cmd
- NAS-Status.cmd
- 01_CHKDSK_F_REPAIR.txt

Ngoài ra phải giữ riêng:
- SSH private key đang dùng để quản trị router.
- SSH config.
- Firmware/OpenWrt backup đã tạo trước đó.
- VeraCrypt Volume Header Backup nếu đã tạo.

Không đưa private key, SMB password hoặc VeraCrypt passphrase vào báo cáo công khai.

## 21. Checklist nhanh

### Sau khi bật router

    /usr/sbin/nas-storage-manager status

Mong đợi:
- NAS1: rw
- NAS2: rw
- PRIVATE: locked hoặc rw tùy đã unlock
- KSMBD: running nếu có NAS1/NAS2

### Trước khi dùng từ xa

    Test-NetConnection <TAILSCALE_IP> -Port 445

Mong đợi:

    True

### Khi cần PRIVATE

    Unlock-PRIVATE.cmd

### Trước khi rút HDD

    /usr/sbin/nas-storage-manager eject

### Khi thấy USB/I/O error

Dừng ghi nặng, kiểm tra log, nguồn/bridge/HDD trước khi tiếp tục.

## 22. Giới hạn và những gì chưa được chứng minh tuyệt đối

- Các bài test từ xa đã đi qua địa chỉ Tailscale, nhưng không phải mọi test đều được thực hiện từ một ISP/vị trí địa lý khác.
- HDD/USB path từng có reset/I/O error; vài bài test nhỏ PASS không chứng minh đường USB ổn định tuyệt đối khi tải nặng nhiều giờ.
- SMART qua USB-SATA bridge có giới hạn.
- ntfsfix không thay thế đầy đủ Windows chkdsk.
- Không có hệ thống RAID/mirror; HDD này vẫn là single point of failure.
- Tailscale bảo vệ đường truyền mạng nhưng không thay thế backup dữ liệu.


## 23. Kiểm chứng reboot thực tế ngày 2026-09-25

Đã thực hiện bài test reboot thật theo quy trình an toàn:

1. Chạy:

    /usr/sbin/nas-storage-manager eject

Kết quả:

    All NAS volumes unmounted. Safe to unplug the managed HDD.

2. Reboot router bằng lệnh:

    reboot

3. Sau khi router lên lại, uptime lúc kiểm tra khoảng 3 phút.

Kết quả sau boot:
- /dev/sda1 tự mount vào /mnt/nas: RW.
- /dev/sda2 tự mount vào /mnt/nas2: RW.
- PRIVATE không mount.
- /dev/mapper/private: inactive.
- PRIVATE VeraCrypt: LOCKED.
- KSMBD: running.
- Tailscale IPv4 giữ nguyên: <TAILSCALE_IP>.
- TCP 445 qua <TAILSCALE_IP>: PASS.
- \\<TAILSCALE_IP>\NAS1: truy cập PASS.
- \\<TAILSCALE_IP>\NAS2: truy cập PASS.
- \\<TAILSCALE_IP>\PRIVATE: không truy cập được khi khóa, đúng thiết kế.
- UCI KSMBD sau reboot chỉ chứa NAS1 và NAS2; share PRIVATE không tồn tại khi mapper chưa active.
- logread xác nhận multi-volume watchdog tự khởi động sau boot.

Log kernel của lần boot mới:
- HDD HGST được nhận ở SuperSpeed USB.
- /dev/sda và sda1/sda2/sda3 được nhận bình thường.
- Không thấy chuỗi USB reset / I/O error / device offlined trong phần log sau boot được kiểm tra.
- NAS1/NAS2 không trở lại trạng thái NTFS dirty và đã mount RW.

Kết luận bài test reboot:
- Auto-mount NAS1: PASS.
- Auto-mount NAS2: PASS.
- PRIVATE locked-by-default: PASS.
- KSMBD auto-recovery: PASS.
- Tailscale remote SMB: PASS.
- Watchdog boot persistence: PASS.
- Safe eject trước reboot: PASS.
- USB/HDD boot sequence trong lần test này: PASS.

Bước unlock PRIVATE sau reboot vẫn yêu cầu người dùng nhập passphrase tương tác; passphrase không được lưu để tự động hóa bước này.

## 24. Kiểm chứng bổ sung sau reboot và bản vá status

Sau reboot thực tế, đã kiểm tra thêm:

- NAS1 tạo -> đọc -> xóa file qua \\<TAILSCALE_IP>\NAS1: PASS.
- NAS2 tạo -> đọc -> xóa file qua \\<TAILSCALE_IP>\NAS2: PASS.
- Watchdog nas-storage chạy dưới procd:
  - running: true
  - command: /usr/sbin/nas-storage-manager watch
  - respawn được cấu hình.
- dm-crypt được nạp thành công sau boot:
  - dm_crypt
  - dm_mod
  - encrypted_keys
  - trusted
- PRIVATE vẫn LOCKED cho tới khi nhập passphrase thủ công.

Đã phát hiện và sửa một bug nhỏ trong lệnh:

    /usr/sbin/nas-storage-manager status

Trước bản vá, khi PRIVATE đang khóa, status in đúng thông tin nhưng trả exit code 1 vì phép kiểm tra PRIVATE là lệnh cuối của hàm.

Sau bản vá:
- shell syntax check: PASS.
- status khi PRIVATE LOCKED: exit code 0.
- nội dung status vẫn chính xác.
- nas-storage-manager.final trong thư mục báo cáo đã được cập nhật để khớp file đang chạy trên router.

## 25. Kiểm chứng auto-unlock PRIVATE sau reboot

Đã bật chế độ auto-unlock VeraCrypt cho PRIVATE.

Secret được lưu tại:

    /root/.nas-private-passphrase

Quyền file đã kiểm tra:

    -rw------- root root

Tức chỉ root có quyền đọc/ghi.

Service boot:

    /etc/init.d/nas-private-autounlock

đã enable ở:

    /etc/rc.d/S98nas-private-autounlock

Hotplug storage cũng đã được bổ sung để khi HDD được cắm lại sau boot, router sẽ thử auto-unlock PRIVATE một lần.

Sau khi người dùng nhập passphrase đúng một lần bằng:

    /usr/sbin/nas-private-autounlock-setup

router báo:

    Auto-unlock: ENABLED
    PRIVATE: unlocked

Đã thực hiện reboot thật để kiểm chứng.

Kết quả sau reboot:
- Auto-unlock: ENABLED.
- PRIVATE: unlocked.
- /dev/mapper/private tồn tại.
- /dev/mapper/private -> /mnt/private: RW.
- KSMBD: running.
- \\<TAILSCALE_IP>\PRIVATE truy cập thành công qua Tailscale.
- Không cần nhập lại passphrase VeraCrypt sau reboot.

Trạng thái toàn bộ storage sau reboot:
- NAS1: RW.
- NAS2: RW.
- PRIVATE: RW + VeraCrypt auto-unlocked.

Lưu ý bảo mật:
- SMB/Tailscale vẫn kiểm soát truy cập mạng.
- Vì passphrase VeraCrypt được lưu trên flash router, người có root router hoặc chiếm được cả router + HDD có thể làm giảm đáng kể lợi ích bảo mật at-rest của VeraCrypt.
- Có thể tắt auto-unlock bằng:

    /usr/sbin/nas-private-autounlock-disable

Sau khi tắt, PRIVATE hiện đang mở sẽ không bị đóng ngay; muốn đóng mapper thì chạy:

    /usr/sbin/nas-storage-manager lock-private

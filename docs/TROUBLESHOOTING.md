# Troubleshooting — toàn bộ lỗi đã gặp

## HDD không nhận sau reboot

~~~sh
lsusb
block info
lsblk
dmesg | tail -n 200
/usr/sbin/nas-storage-manager status
/usr/sbin/nas-storage-manager reconcile
~~~

Nếu log có USB reset/I/O error: kiểm tra nguồn, bridge USB-SATA, cáp, cổng USB và HDD.

## Share hiện nhưng không mở được

Nguyên nhân từng gặp: KSMBD trỏ vào mountpoint rỗng sau khi disk/mount mất.

~~~sh
mount | grep '/mnt/nas'
uci show ksmbd
~~~

Manager mới chỉ expose share khi mount thật tồn tại.

## Path bị thêm /sd

Dùng trực tiếp:
- /mnt/nas
- /mnt/nas2
- /mnt/private

Không thêm lớp /sd nếu không cần.

## NTFS dirty / mount RO

Không force RW.

~~~sh
ntfsfix -n /dev/sda1
~~~

Repair ưu tiên Windows:

~~~cmd
chkdsk X: /f
~~~

Hệ thống lịch sử từng chạy ntfsfix -d, mount lại NTFS3 RW và SMB RW PASS.

## USB reset / Buffer I/O error / device offlined

Đã từng thấy:
- SuperSpeed USB reset
- Buffer I/O error
- device offlined
- Windows UASPStor reset

Xử lý:
1. powered USB hub;
2. nguồn/bridge khác;
3. cáp khác;
4. SMART HDD;
5. tránh benchmark write nặng đến khi ổn định.

## Tên file tiếng Việt

Mount NTFS3 với iocharset=utf8.

## KSMBD không chạy / share rỗng

~~~sh
/etc/init.d/ksmbd status
uci show ksmbd
logread | grep -i ksmbd
~~~

Trong kiến trúc mới, KSMBD có thể cố ý không chạy khi storage chưa mount.

## PRIVATE không hiện

~~~sh
/usr/sbin/nas-storage-manager status
ls -l /dev/mapper/private
~~~

Unlock:

~~~sh
/usr/sbin/nas-storage-manager unlock-private
~~~

Auto-unlock:

~~~sh
/etc/init.d/nas-private-autounlock enabled
ls -l /root/.nas-private-passphrase
~~~

Không in nội dung keyfile.

## Tailscale ping được nhưng SMB không

~~~powershell
Test-NetConnection <TAILSCALE_IP> -Port 445
~~~

~~~sh
nft list ruleset | grep 445
/etc/init.d/ksmbd status
~~~

## Error 86 / 1326

Sai SMB credential.

~~~sh
ksmbd.adduser -u nas
/etc/init.d/ksmbd restart
~~~

KSMBD password DB riêng với Linux /etc/shadow.

## Error 1219

Windows có session tới cùng server bằng account khác.

~~~cmd
net use
net use \\<TAILSCALE_IP>\NAS1 /delete /y
net use \\<TAILSCALE_IP>\IPC$ /delete /y
cmdkey /list
~~~

## Error 1223 / operation canceled

PC app cũ dùng net use với dấu * nên Windows mở prompt tương tác và có thể cancel dù ô password đúng.

Bản mới dùng WNetAddConnection2W để truyền credential trực tiếp trong memory.

## App treo hàng giờ ở Kết nối

Root cause: network I/O block làm busy=True không được reset.

Fix:
- TCP/445 preflight timeout;
- path timeout;
- task watchdog;
- UI tự unlock sau failure.

## Smart App Control chặn EXE

PyInstaller EXE unsigned có thể bị chặn. Không nên tắt Smart App Control chỉ để chạy app.

Có thể:
- chạy source bằng Python signed;
- code-sign EXE bằng certificate phù hợp.

## Flutter Windows yêu cầu symlink

Plugin Windows cần Developer Mode. PC app cuối dùng Python native SMB nên không phụ thuộc Flutter Windows.

## Kotlin cross-drive cache

Project Flutter ở D: nhưng Pub cache ở C: từng lỗi incremental cache.

Fix:

~~~properties
kotlin.incremental=false
~~~

## SMB chậm

Kiểm tra:
- Tailscale direct hay DERP;
- CPU MT7621;
- USB 3 path;
- NTFS overhead;
- HDD power;
- USB-SATA bridge;
- nhiều file nhỏ vs file lớn.

Không mở WAN 445 để tăng tốc.
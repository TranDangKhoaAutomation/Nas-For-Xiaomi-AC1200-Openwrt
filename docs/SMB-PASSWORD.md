# SMB Password / Windows Credentials

## Đổi password KSMBD

~~~sh
ksmbd.adduser -u nas
/etc/init.d/ksmbd restart
~~~

Kiểm tra user tồn tại mà không in hash:

~~~sh
grep '^nas:' /etc/ksmbd/ksmbdpwd.db | sed 's/:.*/:[REDACTED]/'
~~~

## Windows vẫn báo sai password

~~~cmd
net use
net use \\<TAILSCALE_IP>\NAS1 /delete /y
net use \\<TAILSCALE_IP>\NAS2 /delete /y
net use \\<TAILSCALE_IP>\PRIVATE /delete /y
net use \\<TAILSCALE_IP>\IPC$ /delete /y
cmdkey /list
~~~

Mã lỗi:
- 86: password sai
- 1326: username/password sai
- 1219: credential conflict
- 1223: prompt/cancel

PC app mới dùng WNet API, không dùng net use với dấu *.
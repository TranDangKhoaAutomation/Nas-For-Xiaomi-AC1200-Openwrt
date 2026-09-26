# Security model

## Nguyên tắc

1. Không expose SMB TCP/445 trực tiếp ra WAN.
2. Remote SMB đi qua Tailscale.
3. Repo public không chứa password/hash/private key/Tailscale state/VeraCrypt keyfile.
4. SMB user hiện là nas; password phải đặt riêng.
5. PRIVATE auto-unlock là lựa chọn có trade-off.
6. EXE Windows unsigned có thể bị Smart App Control block.

## Secret tuyệt đối không commit

- /etc/shadow
- /etc/dropbear/*_host_key
- /etc/ksmbd/ksmbdpwd.db
- /root/.nas-private-passphrase
- Tailscale state/auth key
- SSH client private key
- full private sysupgrade backup
- Wi-Fi PSK thật

Nếu secret từng bị commit:
- rotate secret;
- xóa khỏi Git history;
- không chỉ xóa file trong commit mới.

## Auto-unlock PRIVATE

Auto-unlock tiện nhưng secret nằm trên flash router. Nếu router bị chiếm vật lý hoặc root compromise, secret có thể bị lấy.

Nếu ưu tiên confidentiality, dùng manual unlock.

## Backup

Public sanitized backup dùng để chia sẻ.

Private full backup phải cất offline hoặc encrypted.

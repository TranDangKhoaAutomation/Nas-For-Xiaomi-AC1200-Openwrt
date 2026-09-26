# Security

Repo này public. Không commit:
- /etc/shadow
- /etc/dropbear/*_host_key
- SSH private key
- /etc/ksmbd/ksmbdpwd.db
- Wi-Fi password/key
- Tailscale auth key hoặc state
- VeraCrypt passphrase
- /root/.nas-private-passphrase
- raw sysupgrade config backup chưa audit

backups/public là SANITIZED.

Remote SMB:
- LAN/tailnet: được phép theo firewall.
- WAN TCP/445: phải REJECT.
- Không port-forward 445.

PRIVATE:
- manual unlock an toàn hơn;
- auto-unlock lưu keyfile root-only 0600;
- nếu mất cả router + HDD thì lợi ích mã hóa giảm.

Filesystem:
- không force dirty NTFS RW;
- ưu tiên data integrity hơn availability.

Nếu lỡ commit secret:
1. đổi/revoke secret ngay;
2. rewrite Git history;
3. force-push lịch sử sạch;
4. kiểm tra fork/clone/cache.
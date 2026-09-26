# Backups

Public sanitized archive:

backups/public/OpenWrt_Backup_Xiaomi_Mi_Router_3G_2026-09-24_SANITIZED.zip

- Size: 23,354,685 bytes
- SHA-256: 2ea1b8406b91d7cc09ee50397f1f5e9b3e0f974d5dc077554434ef02cb323d79

Original private backup is intentionally not uploaded.

Historical original SHA-256:
006b2b8a4a36236558a7db954d43c772bebf43e7794bc467a4468d0e6ba0a143

Reason: the raw archive contains /etc/shadow, Dropbear host keys and Wi-Fi/UCI secrets.

Use scripts/windows/Create-Private-Backup.ps1 to create a fresh private backup.

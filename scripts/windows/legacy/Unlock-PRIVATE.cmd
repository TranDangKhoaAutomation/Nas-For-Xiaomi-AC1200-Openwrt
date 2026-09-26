@echo off
title OpenWrt NAS - Unlock PRIVATE
set "SSH=%SystemRoot%\System32\OpenSSH\ssh.exe"
set "CFG=%USERPROFILE%\OneDrive\Documents\Codex\openwrt_ssh_config"
"%SSH%" -t -F "%CFG%" owrt "/usr/sbin/nas-storage-manager unlock-private"
echo.
pause

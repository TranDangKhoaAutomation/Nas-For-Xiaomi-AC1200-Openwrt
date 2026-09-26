@echo off
title OpenWrt NAS - Status
set "SSH=%SystemRoot%\System32\OpenSSH\ssh.exe"
set "CFG=%USERPROFILE%\OneDrive\Documents\Codex\openwrt_ssh_config"
"%SSH%" -F "%CFG%" owrt "/usr/sbin/nas-storage-manager status"
echo.
pause

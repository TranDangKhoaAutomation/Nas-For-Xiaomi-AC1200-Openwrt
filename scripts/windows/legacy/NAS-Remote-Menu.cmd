@echo off
setlocal
title OpenWrt NAS Remote Menu
set "SSH=%SystemRoot%\System32\OpenSSH\ssh.exe"
set "CFG=%USERPROFILE%\OneDrive\Documents\Codex\openwrt_ssh_config"
set "TSIP=100.64.0.1"

:menu
cls
echo ================================
echo       OpenWrt NAS Remote
echo ================================
echo 1. Open NAS1
echo 2. Open NAS2
echo 3. Open PRIVATE
echo 4. Unlock PRIVATE
echo 5. Lock PRIVATE
echo 6. Show NAS status
echo 7. Safe eject HDD
echo 0. Exit
echo.
choice /c 12345670 /n /m "Choose: "
if errorlevel 8 goto end
if errorlevel 7 goto eject
if errorlevel 6 goto status
if errorlevel 5 goto lock
if errorlevel 4 goto unlock
if errorlevel 3 goto private
if errorlevel 2 goto nas2
if errorlevel 1 goto nas1

:nas1
start "" "\\%TSIP%\NAS1"
goto menu

:nas2
start "" "\\%TSIP%\NAS2"
goto menu

:private
start "" "\\%TSIP%\PRIVATE"
goto menu

:unlock
"%SSH%" -t -F "%CFG%" owrt "/usr/sbin/nas-storage-manager unlock-private"
pause
goto menu

:lock
"%SSH%" -F "%CFG%" owrt "/usr/sbin/nas-storage-manager lock-private"
pause
goto menu

:status
"%SSH%" -F "%CFG%" owrt "/usr/sbin/nas-storage-manager status"
pause
goto menu

:eject
echo.
choice /c YN /n /m "Unmount all NAS volumes and close PRIVATE mapper? [Y/N] "
if errorlevel 2 goto menu
"%SSH%" -F "%CFG%" owrt "/usr/sbin/nas-storage-manager eject"
pause
goto menu

:end
endlocal

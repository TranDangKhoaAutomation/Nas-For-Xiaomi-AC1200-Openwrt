param([string]$HostAddress = "100.91.1.101")

foreach ($share in @("NAS1","NAS2","PRIVATE","IPC$")) {
  cmd /c "net use \\$HostAddress\$share /delete /y >nul 2>&1"
}
Write-Host "Đã yêu cầu Windows xóa SMB session tới $HostAddress."

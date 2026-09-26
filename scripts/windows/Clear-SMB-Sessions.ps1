param([Parameter(Mandatory=$true)][string]$HostName)

$shares = @("NAS1","NAS2","PRIVATE","IPC$")
foreach ($share in $shares) {
    cmd /c "net use \\$HostName\$share /delete /y" | Out-Null
}

Write-Host "Đã yêu cầu xóa SMB sessions tới $HostName."
cmdkey /list

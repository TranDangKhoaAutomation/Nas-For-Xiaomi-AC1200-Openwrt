param(
  [string]$SshConfig = "$HOME\.ssh\config",
  [string]$HostAlias = "owrt",
  [string]$User = "nas"
)

Write-Host "Đổi mật khẩu SMB cho user $User" -ForegroundColor Cyan
ssh -t -F $SshConfig $HostAlias "/usr/sbin/ksmbd.adduser -u $User"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
ssh -F $SshConfig $HostAlias "/etc/init.d/ksmbd restart"

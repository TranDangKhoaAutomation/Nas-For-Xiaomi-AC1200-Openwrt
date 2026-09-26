param(
  [string]$SshConfig = "$HOME\.ssh\config",
  [string]$HostAlias = "owrt"
)

ssh -F $SshConfig $HostAlias "/usr/sbin/nas-storage-manager status"

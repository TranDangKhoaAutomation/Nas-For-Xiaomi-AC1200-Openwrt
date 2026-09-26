param(
  [string]$SshConfig = "$HOME\.ssh\config",
  [string]$HostAlias = "owrt"
)

ssh -t -F $SshConfig $HostAlias "/usr/sbin/nas-storage-manager unlock-private"

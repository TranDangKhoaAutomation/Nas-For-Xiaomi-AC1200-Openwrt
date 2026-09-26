param(
    [string]$SshTarget = "root@192.168.1.1",
    [string]$SshConfig = "$HOME\.ssh\config",
    [string]$OutputDir = ".\private-backups"
)

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$remote = "/tmp/openwrt-private-backup-$stamp.tar.gz"

ssh -F $SshConfig $SshTarget "sysupgrade -b $remote && sha256sum $remote"
$sourceSpec = "$($SshTarget):$remote"
scp -F $SshConfig $sourceSpec "$OutputDir\"
ssh -F $SshConfig $SshTarget "rm -f $remote"

Get-FileHash "$OutputDir\openwrt-private-backup-$stamp.tar.gz" -Algorithm SHA256
Write-Warning "PRIVATE backup có thể chứa password/key. Không upload public."

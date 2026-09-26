param(
    [string]$SshTarget = "root@192.168.1.1",
    [string]$SshConfig = "$HOME\.ssh\config",
    [string]$User = "nas"
)

ssh -t -F $SshConfig $SshTarget "/usr/sbin/ksmbd.adduser -u '$User'"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
ssh -F $SshConfig $SshTarget "/etc/init.d/ksmbd restart; /etc/init.d/ksmbd status"

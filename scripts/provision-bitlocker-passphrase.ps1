# Run locally on this Windows PC. The passphrase is read without echo and sent
# through the verified SSH host key; it is never passed on the command line.
$ErrorActionPreference = 'Stop'
$sshDir = Join-Path $env:USERPROFILE '.ssh'
$identity = Join-Path $sshDir 'openwrt_nas_ed25519'
$knownHosts = Join-Path $sshDir 'openwrt_current_known_hosts'
if (-not (Test-Path -LiteralPath $identity) -or -not (Test-Path -LiteralPath $knownHosts)) {
    throw 'SSH identity or pinned router host key is missing.'
}
$hostFingerprint = & ssh-keygen -lf $knownHosts
if ($LASTEXITCODE -ne 0 -or $hostFingerprint -notmatch 'SHA256:qXMHQKUxALpxCzg0HamL7k1HXT38gzDdK5LEGvyqOVA') {
    throw 'Pinned router host fingerprint does not match the verified value.'
}

$secure = Read-Host 'Nhap mat khau BitLocker cua phan vung sdb3 (khong hien ky tu)' -AsSecureString
$bstr = [IntPtr]::Zero
$plain = $null
$bytes = $null
try {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    if ([string]::IsNullOrEmpty($plain)) { throw 'Password is empty.' }
    $bytes = [Text.Encoding]::UTF8.GetBytes($plain)

    $procInfo = New-Object Diagnostics.ProcessStartInfo
    $procInfo.FileName = 'ssh.exe'
    $procInfo.Arguments = '-i "' + $identity + '" -o UserKnownHostsFile="' + $knownHosts + '" -o StrictHostKeyChecking=yes -o BatchMode=yes root@100.114.53.95 /usr/sbin/nas-bitlocker-provision'
    $procInfo.UseShellExecute = $false
    $procInfo.RedirectStandardInput = $true
    $procInfo.RedirectStandardOutput = $true
    $procInfo.RedirectStandardError = $true
    $procInfo.CreateNoWindow = $true
    $proc = [Diagnostics.Process]::Start($procInfo)
    try {
        $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
        $proc.StandardInput.Close()
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        if ($stdout) { Write-Host $stdout.TrimEnd() }
        if ($stderr) { Write-Host $stderr.TrimEnd() }
        if ($proc.ExitCode -ne 0) { throw "Provisioning failed (exit $($proc.ExitCode))." }
    } finally {
        $proc.Dispose()
    }
} finally {
    if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
    $plain = $null
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $secure.Dispose()
}

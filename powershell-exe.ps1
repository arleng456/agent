# ============================================================
# ST PILOT - Nezha Agent One-Step Installer
# Downloaded and executed automatically via web link
# ============================================================

$Config = @{
    NZ_SERVER        = "154.39.0.168:8008"
    NZ_TLS           = "false"
    NZ_CLIENT_SECRET = "x5tB8RDqqErqyQNmoP415AfcerBz4A5g"
    InstallerUrl     = "https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.ps1"
    InstallerPath    = "C:\install.ps1"
    LogDir           = "$env:LOCALAPPDATA\ST-PILOT\logs"
}

# --- Logging ---
if (!(Test-Path $Config.LogDir)) { New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null }
$LogFile = "$($Config.LogDir)\install-$((Get-Date -Format 'yyyyMMdd-HHmmss')).log"

function Write-Log($msg, $level = "INFO") {
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] [$level] $msg"
    $entry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    if ($level -eq "ERROR") { Write-Host $entry -ForegroundColor Red }
    elseif ($level -eq "WARN") { Write-Host $entry -ForegroundColor Yellow }
    elseif ($level -eq "OK") { Write-Host $entry -ForegroundColor Green }
}

Write-Log "ST PILOT agent installer started"
Write-Log "User: $env:USERNAME | Machine: $env:COMPUTERNAME"

# --- Admin check with UAC elevation ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "Requesting admin elevation..." "WARN"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb = "RunAs"
    $psi.UseShellExecute = $true
    Start-Process -FilePath $psi.FileName -ArgumentList $psi.Arguments -Verb RunAs -Wait
    exit $LASTEXITCODE
}

Write-Log "Admin rights confirmed" "OK"

# --- Set machine-level env vars (persistent after reboot) ---
Write-Log "Setting machine environment variables"
[Environment]::SetEnvironmentVariable("NZ_SERVER", $Config.NZ_SERVER, "Machine")
[Environment]::SetEnvironmentVariable("NZ_TLS", $Config.NZ_TLS, "Machine")
[Environment]::SetEnvironmentVariable("NZ_CLIENT_SECRET", $Config.NZ_CLIENT_SECRET, "Machine")
Write-Log "NZ_SERVER=$($Config.NZ_SERVER) | NZ_TLS=$($Config.NZ_TLS)" "OK"

# --- Set ExecutionPolicy persistently ---
Write-Log "Setting ExecutionPolicy to RemoteSigned (machine scope)"
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue

# --- Download installer ---
Write-Log "Downloading Nezha installer from GitHub..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3 -bor
        [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor
        [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Config.InstallerUrl -OutFile $Config.InstallerPath -UseBasicParsing -ErrorAction Stop
    Write-Log "Installer downloaded to $($Config.InstallerPath)" "OK"
} catch {
    Write-Log "Download failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

# --- Run installer (hidden) ---
Write-Log "Running Nezha agent installer..."
$proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($Config.InstallerPath)`"" `
    -Wait -PassThru -WindowStyle Hidden

if ($proc.ExitCode -eq 0) {
    Write-Log "Agent installed successfully. Service will auto-start on boot." "OK"
} else {
    Write-Log "Installer exited with code: $($proc.ExitCode)" "WARN"
}

Write-Log "Session ended. Log: $LogFile"
Write-Host "`nAgent installation complete. Check logs at: $LogFile`n" -ForegroundColor Cyan
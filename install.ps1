param(
    [string]$TaskName = "llogin",
    [switch]$CreateShortcut,
    [switch]$InstallOnly
)

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $InstallOnly -and -not $IsAdmin) {
    Write-Host "Administrator privileges required for task scheduler setup. Requesting elevation..." -ForegroundColor Yellow
    
    try {
        $ArgumentList = @()
        if ($CreateShortcut) { $ArgumentList += "-CreateShortcut" }
        if ($InstallOnly) { $ArgumentList += "-InstallOnly" }
        
        $Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`" " + ($ArgumentList -join " ")
        
        Start-Process -FilePath "powershell.exe" -ArgumentList $Arguments -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host "Failed to elevate privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "You can run with -InstallOnly to avoid requiring admin privileges." -ForegroundColor Yellow
        pause
        exit 1
    }
}

Write-Host "llogin Installer" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$LLoginUrl = "https://raw.githubusercontent.com/saddexed/llogin/main/llogin.ps1"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\llogin"
$TargetFile = Join-Path $InstallDir "llogin.ps1"
$TargetCmdFile = Join-Path $InstallDir "llogin.cmd"

if (-not (Test-Path $InstallDir)) {
    Write-Host "Creating installation directory: $InstallDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$SourceFile = Join-Path $PSScriptRoot "llogin.ps1"
if (Test-Path $SourceFile) {
    Write-Host "Installing llogin.ps1 from local directory..." -ForegroundColor Cyan
    try {
        Copy-Item -Path $SourceFile -Destination $TargetFile -Force
        Write-Host "llogin.ps1 installed from local file" -ForegroundColor Green
    } catch {
        Write-Host "Error copying llogin.ps1: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Downloading llogin.ps1 from GitHub..." -ForegroundColor Cyan
    try {
        $LLoginContent = Invoke-RestMethod -Uri $LLoginUrl
        $LLoginContent | Out-File -FilePath $TargetFile -Encoding UTF8
        Write-Host "llogin.ps1 downloaded" -ForegroundColor Green
    } catch {
        Write-Host "Error downloading llogin.ps1: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please check your internet connection and GitHub URL." -ForegroundColor Yellow
        exit 1
    }
}

if (Test-Path $TargetCmdFile) {
    Write-Host "File llogin.cmd already exists in $InstallDir. Overwriting..." -ForegroundColor Yellow
}

try {
    Write-Host "Creating llogin.cmd batch file..." -ForegroundColor Cyan
    $CmdContent = @"
@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$TargetFile" %*
"@
    $CmdContent | Out-File -FilePath $TargetCmdFile -Encoding ASCII
    Write-Host "llogin.cmd created" -ForegroundColor Green
} catch {
    Write-Host "Error creating llogin.cmd: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

try {
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        Write-Host "Adding installation directory to PATH..." -ForegroundColor Cyan
        $NewUserPath = if ($UserPath) { "$UserPath;$InstallDir" } else { $InstallDir }
        [Environment]::SetEnvironmentVariable("PATH", $NewUserPath, "User")
        Write-Host "Installation directory added to PATH" -ForegroundColor Green
        Write-Host "Note: You may need to restart your terminal for PATH changes to take effect" -ForegroundColor Yellow
    } else {
        Write-Host "Installation directory already in PATH" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Warning: Could not update PATH environment variable: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    $ProfilePath = $PROFILE.CurrentUserAllHosts
    $ProfileDir = Split-Path $ProfilePath -Parent
    
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }
    
    $AliasCommand = "Set-Alias -Name llogin -Value `"$TargetFile`""
    
    if (Test-Path $ProfilePath) {
        $ProfileContent = Get-Content $ProfilePath -Raw
        if ($ProfileContent -notmatch "Set-Alias.*llogin") {
            Write-Host "Adding PowerShell alias to profile..." -ForegroundColor Cyan
            Add-Content -Path $ProfilePath -Value "`n# LLogin alias"
            Add-Content -Path $ProfilePath -Value $AliasCommand
            Write-Host "PowerShell alias added" -ForegroundColor Green
        } else {
            Write-Host "PowerShell alias already exists in profile" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Creating PowerShell profile with alias..." -ForegroundColor Cyan
        "# PowerShell Profile`n# LLogin alias`n$AliasCommand" | Out-File -FilePath $ProfilePath -Encoding UTF8
        Write-Host "PowerShell profile created with alias" -ForegroundColor Green
    }
} catch {
    Write-Host "Warning: Could not set up PowerShell alias: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($CreateShortcut) {
    try {
        $DesktopPath = [Environment]::GetFolderPath("Desktop")
        $ShortcutPath = Join-Path $DesktopPath "llogin.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetFile`""
        $Shortcut.WorkingDirectory = $InstallDir
        $Shortcut.Description = "LPU Auto Wireless Login"
        $Shortcut.Save()
        
        Write-Host "Desktop shortcut created: $ShortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($InstallOnly) {
    Write-Host ""
    Write-Host "Installation completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Manual Usage:" -ForegroundColor Cyan
    Write-Host "============" -ForegroundColor Cyan
    Write-Host "1. Edit credentials in: $TargetFile" -ForegroundColor White
    Write-Host "2. Run manually: llogin username password" -ForegroundColor White
    Write-Host ""
    Write-Host "To set up automatic login later, run this script again without -InstallOnly" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

if (-not $IsAdmin) {
    Write-Host "Error: Administrator privileges required for task scheduler setup." -ForegroundColor Red
    Write-Host "The login script has been installed, but automatic scheduling was skipped." -ForegroundColor Yellow
    exit 1
}

$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    try {
        Write-Host "Removing existing task $TaskName..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    } catch {
        Write-Host "Warning: Could not remove existing task: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$TaskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff")</Date>
    <Author>$($env:COMPUTERNAME)\$($env:USERNAME)</Author>
    <URI>\$TaskName</URI>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NCSI/Operational"&gt;&lt;Select Path="Microsoft-Windows-NCSI/Operational"&gt;*[System[Provider[@Name='Microsoft-Windows-NCSI'] and EventID=4038]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$($env:COMPUTERNAME)\$($env:USERNAME)</UserId>
      <LogonType>S4U</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>StopExisting</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -File "$TargetFile"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Write-Host "Creating scheduled task $TaskName..." -ForegroundColor Cyan

try {
    $TempXMLPath = Join-Path $env:TEMP "LPU-Task-$([System.Guid]::NewGuid().ToString()).xml"
    $TaskXML | Out-File -FilePath $TempXMLPath -Encoding Unicode
    
    schtasks /create /tn "$TaskName" /xml "$TempXMLPath" /f
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Scheduled task created successfully!" -ForegroundColor Green
        
        Remove-Item $TempXMLPath -Force -ErrorAction SilentlyContinue
        
    } else {
        throw "schtasks command failed with exit code $LASTEXITCODE"
    }
    
} catch {
    Write-Host "Error creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    
    if (Test-Path $TempXMLPath) {
        Remove-Item $TempXMLPath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "The login script was installed successfully, but automatic scheduling failed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "INSTALLATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
if ($CreateShortcut) { 
    Write-Host "Desktop shortcut: Created" -ForegroundColor Green 
}
Write-Host ""
Write-Host "Configuration Required:" -ForegroundColor Yellow
Write-Host "======================" -ForegroundColor Yellow
Write-Host "IMPORTANT: Edit your credentials in the login script:" -ForegroundColor Red
Write-Host "  File: $TargetFile" -ForegroundColor White
Write-Host "  Set your LPU username and password in the script variables" -ForegroundColor White
Write-Host ""
Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "======" -ForegroundColor Cyan
Write-Host "- PowerShell: llogin username password" -ForegroundColor White
Write-Host "- CMD: llogin username password" -ForegroundColor White
Write-Host "- With defaults: llogin" -ForegroundColor White
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "- View task: Get-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host "- Run manually: Start-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: Restart your terminal to use the 'llogin' command" -ForegroundColor Yellow

if (-not $CreateShortcut) {
    Write-Host ""
    $CreateShortcutChoice = Read-Host "Would you like to create a desktop shortcut for manual login? (y/N)"
    if ($CreateShortcutChoice -match "^[Yy]") {
        try {
            $DesktopPath = [Environment]::GetFolderPath("Desktop")
            $ShortcutPath = Join-Path $DesktopPath "llogin.lnk"
            
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
            $Shortcut.TargetPath = "powershell.exe"
            $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetFile`""
            $Shortcut.WorkingDirectory = $InstallDir
            $Shortcut.Description = "LPU Auto Wireless Login"
            $Shortcut.Save()
            
            Write-Host "Desktop shortcut created: $ShortcutPath" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
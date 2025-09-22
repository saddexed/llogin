param(
    [string]$TaskName = "llogin",
    [switch]$CreateShortcut,
    [switch]$InstallOnly
)

# Check if running as administrator for scheduler operations
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

# Configuration
$SourceFile = Join-Path $PSScriptRoot "llogin.ps1"
$UserRootDir = $env:USERPROFILE
$TargetFile = Join-Path $UserRootDir "llogin.ps1"

# Check source file exists
if (-not (Test-Path $SourceFile)) {
    Write-Host "Error: Source file 'llogin.ps1' not found in the current directory." -ForegroundColor Red
    Write-Host "Please run this script from the directory containing llogin.ps1" -ForegroundColor Red
    exit 1
}

# Check if target file already exists and inform user
if (Test-Path $TargetFile) {
    Write-Host "File llogin.ps1 already exists in $UserRootDir. Overwriting..." -ForegroundColor Yellow
}

# Copy the file to user's root directory
try {
    Write-Host "Copying llogin.ps1 to user directory (${TargetFile})..." -ForegroundColor Cyan
    Copy-Item -Path $SourceFile -Destination $TargetFile -Force
    Write-Host "llogin installed" -ForegroundColor Green
} catch {
    Write-Host "Error copying file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create desktop shortcut if requested
if ($CreateShortcut) {
    try {
        $DesktopPath = [Environment]::GetFolderPath("Desktop")
        $ShortcutPath = Join-Path $DesktopPath "llogin.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetFile`""
        $Shortcut.WorkingDirectory = $UserRootDir
        $Shortcut.Description = "LPU Auto Wireless Login"
        $Shortcut.Save()
        
        Write-Host "Desktop shortcut created: $ShortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Skip scheduler setup if InstallOnly is specified
if ($InstallOnly) {
    Write-Host ""
    Write-Host "Installation completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Manual Usage:" -ForegroundColor Cyan
    Write-Host "============" -ForegroundColor Cyan
    Write-Host "1. Edit credentials in: $TargetFile" -ForegroundColor White
    Write-Host "2. Run manually: powershell -File `"$TargetFile`"" -ForegroundColor White
    Write-Host ""
    Write-Host "To set up automatic login later, run this script again without -InstallOnly" -ForegroundColor Yellow
    exit 0
}

# Step 2: Create Scheduled Task
Write-Host ""

if (-not $IsAdmin) {
    Write-Host "Error: Administrator privileges required for task scheduler setup." -ForegroundColor Red
    Write-Host "The login script has been installed, but automatic scheduling was skipped." -ForegroundColor Yellow
    exit 1
}

# Get current user information
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$UserSID = $CurrentUser.User.Value

# Check if task already exists and remove it if necessary
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    try {
        Write-Host "Removing existing task $TaskName..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    } catch {
        Write-Host "Warning: Could not remove existing task: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create the XML template with dynamic values
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
      <Command>pwsh</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -File "$TargetFile"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Write-Host "Creating scheduled task $TaskName..." -ForegroundColor Cyan

try {
    # Create a temporary XML file
    $TempXMLPath = Join-Path $env:TEMP "LPU-Task-$([System.Guid]::NewGuid().ToString()).xml"
    $TaskXML | Out-File -FilePath $TempXMLPath -Encoding Unicode
    
    # Register the task using the XML file
    schtasks /create /tn "$TaskName" /xml "$TempXMLPath" /f
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Scheduled task created successfully!" -ForegroundColor Green
        
        # Clean up temporary file
        Remove-Item $TempXMLPath -Force -ErrorAction SilentlyContinue
        
    } else {
        throw "schtasks command failed with exit code $LASTEXITCODE"
    }
    
} catch {
    Write-Host "Error creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    
    # Clean up temporary file if it exists
    if (Test-Path $TempXMLPath) {
        Remove-Item $TempXMLPath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "The login script was installed successfully, but automatic scheduling failed." -ForegroundColor Yellow
    exit 1
}

# Final success message and instructions
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
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "- View task: Get-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host "- Run manually: Start-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host "- Run login script: powershell -File `"$TargetFile`"" -ForegroundColor White

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
            $Shortcut.WorkingDirectory = $UserRootDir
            $Shortcut.Description = "LPU Auto Wireless Login"
            $Shortcut.Save()
            
            Write-Host "Desktop shortcut created: $ShortcutPath" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
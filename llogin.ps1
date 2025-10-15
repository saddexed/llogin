param(
    [string]$Username,
    [string]$Password,
    [switch]$Help,
    [switch]$Stop,
    [switch]$Start,
    [switch]$Logout,
    [switch]$SetCreds,
    [switch]$ShowCreds,
    [switch]$ClearCreds,
    [switch]$Update,
    [switch]$Version,
    [switch]$Monitor
)
$CurrentVersion = "1.0.2"
if ($Version) {
    Write-Host "llogin version $CurrentVersion" -ForegroundColor Cyan
    exit 0
}

# Configure TLS and certificate validation for both PowerShell 5.1 and 7+
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

function Write-ColorOutput {
    param([string]$Message,[string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
}

function Write-LogEntry {
    param(
        [string]$Username,
        [string]$Action,
        [string]$Status,
        [string]$Url = ""
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$Timestamp - $Action $Status for user: $Username"
    if ($Url) {
        $LogMessage += " via $Url"
    }
    Add-Content -Path 'log.txt' -Value $LogMessage
}

function Get-LoggedInUser {
    try {
        $ClientPageUrl = "https://10.10.0.1/24online/webpages/client.jsp"
        
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $Response = Invoke-WebRequest -Uri $ClientPageUrl -Method GET -SkipCertificateCheck -ErrorAction Stop
        } else {
            $Response = Invoke-WebRequest -Uri $ClientPageUrl -Method GET -ErrorAction Stop
        }
        
        if ($Response.Content -match 'name="loggedinuser"\s+value="([^"]+)"') {
            $Username = $matches[1] -replace '@lpu\.com$', ''
            Write-ColorOutput "Detected logged-in user: $Username" Green
            return $Username
        } else {
            Write-ColorOutput "No logged-in user detected (may not be logged in)" Yellow
            return $null
        }
        
    } catch {
        Write-ColorOutput "Error detecting logged-in user: $($_.Exception.Message)" Red
        Write-ColorOutput "This usually means you're not logged in or not connected to LPU network" Yellow
        return $null
    }
}

function Get-LatestGitHubRelease {
    
    try {
        $ApiUrl = "https://api.github.com/repos/saddexed/llogin/releases/latest"
        $Response = Invoke-RestMethod -Uri $ApiUrl -Method GET -ErrorAction Stop
        
        return @{
            Version = $Response.tag_name -replace '^v', ''
            ReleaseUrl = $Response.html_url
            DownloadUrl = $Response.zipball_url
            PublishedAt = $Response.published_at
            Body = $Response.body
        }
    } catch {
        Write-ColorOutput "Error checking for updates: $($_.Exception.Message)" Red
        return $null
    }
}

function Compare-Versions {
    param(
        [string]$CurrentVersion,
        [string]$LatestVersion
    )
    
    try {
        $current = [version]$CurrentVersion
        $latest = [version]$LatestVersion
        
        if ($latest -gt $current) {
            return 1  # Update available
        } elseif ($latest -eq $current) {
            return 0  # Same version
        } else {
            return -1 # Current is newer
        }
    } catch {
        # Fallback to string comparison if version parsing fails
        return [string]::Compare($LatestVersion, $CurrentVersion)
    }
}

function Invoke-Update {
    $LatestRelease = Get-LatestGitHubRelease
    
    if (-not $LatestRelease) {
        Write-ColorOutput "Unable to check for updates. Please check your internet connection." Red
        return $false
    }
    
    $LatestVersion = $LatestRelease.Version
    $VersionComparison = Compare-Versions $CurrentVersion $LatestVersion
    
    if ($VersionComparison -le 0) {
        Write-ColorOutput "You're already running the latest version ($CurrentVersion)" Green
        return $true
    }
    
    # Show version information and prompt for update
    Write-ColorOutput "A new version is available!" Cyan
    Write-ColorOutput "Current Version: $CurrentVersion" Yellow
    Write-ColorOutput "Latest Version: $LatestVersion" Green
    
    # Prompt user to confirm update
    $prompt = Read-Host "Do you want to download and install the update? (y/N)"
    if ($prompt -notmatch '^[Yy]$') {
        return $false
    }
    
    Write-Host "Updating from $CurrentVersion to $LatestVersion..." -ForegroundColor Yellow
    
    try {
        $TempDir = Join-Path $env:TEMP "llogin-update-$([System.Guid]::NewGuid().ToString())"
        $ZipPath = Join-Path $TempDir "llogin-latest.zip"
        
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        
        Write-ColorOutput "Downloading latest version..." Cyan
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Invoke-WebRequest -Uri $LatestRelease.DownloadUrl -OutFile $ZipPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $LatestRelease.DownloadUrl -OutFile $ZipPath -ErrorAction Stop
        }
        
        Write-ColorOutput "Extracting update..." Cyan
        Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
        
        # Find the extracted folder (GitHub releases create a folder with repo name and commit hash)
        $ExtractedFolders = Get-ChildItem -Path $TempDir -Directory
        $SourceFolder = $ExtractedFolders | Where-Object { $_.Name -like "*llogin*" } | Select-Object -First 1
        
        if (-not $SourceFolder) {
            throw "Could not find llogin files in the downloaded archive"
        }
        
        $NewScriptPath = Join-Path $SourceFolder.FullName "llogin.ps1"
        
        if (-not (Test-Path $NewScriptPath)) {
            throw "llogin.ps1 not found in the downloaded archive"
        }
        
        # Backup current script
        $BackupPath = "$PSCommandPath.backup"
        Write-ColorOutput "Creating backup..." Yellow
        Copy-Item -Path $PSCommandPath -Destination $BackupPath -Force
        
        # Replace current script
        Write-ColorOutput "Installing update..." Green
        Copy-Item -Path $NewScriptPath -Destination $PSCommandPath -Force
        
        # Cleanup
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-ColorOutput "Update completed successfully!" Green
        Write-ColorOutput "Backup saved to: $BackupPath" Gray
        Write-Host ""
        Write-ColorOutput "Run 'llogin -Help' to see any new features." Cyan
        
        return $true
        
    } catch {
        Write-ColorOutput "Update failed: $($_.Exception.Message)" Red
        
        # Cleanup on error
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return $false
    }
}

if ($Help) {
    Write-Host "LLogin - LPU Wifi Autologin" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  llogin                          Login with stored/default credentials" -ForegroundColor White
    Write-Host "  llogin <username> <password>    Login with specified credentials" -ForegroundColor White
    Write-Host "  llogin -h, -help                Shows this help message" -ForegroundColor White
    Write-Host "  llogin -l, -logout              Logout" -ForegroundColor White
    Write-Host "  llogin -set, -setcreds          Store default credentials" -ForegroundColor White
    Write-Host "  llogin -show, -showcreds        Show current credential status" -ForegroundColor White
    Write-Host "  llogin -clear, -clearcreds      Remove stored credentials" -ForegroundColor White
    Write-Host "  llogin -start                   Start and enable the scheduled task" -ForegroundColor White
    Write-Host "  llogin -stop                    Stop and disable the scheduled task" -ForegroundColor White
    Write-Host "  llogin -u, -update              Check for updates and optionally install" -ForegroundColor White
    Write-Host "  llogin -monitor                 Run in background monitoring mode" -ForegroundColor White
    exit 0
}

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# Auto-elevate for commands that require admin privileges
if (($Start -or $Stop) -and -not $IsAdmin) {
    Write-Host "Administrator privileges required for task scheduler management. Requesting elevation..." -ForegroundColor Yellow
    
    try {
        $ArgumentList = @()
        if ($Start) { $ArgumentList += "-Start" }
        if ($Stop) { $ArgumentList += "-Stop" }
        if ($Username) { $ArgumentList += $Username }
        if ($Password) { $ArgumentList += $Password }
        
        $Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`" " + ($ArgumentList -join " ")
        
        Start-Process -FilePath "powershell.exe" -ArgumentList $Arguments -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host "Failed to elevate privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        exit 1
    }
}

if ($Start) {
    $TaskName = "llogin"

    try {
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Write-Host "Found scheduled task '$TaskName'. Current state: $($ExistingTask.State)" -ForegroundColor Cyan
            
            if ($ExistingTask.State -eq "Disabled") {
                Write-Host "Enabling scheduled task '$TaskName'..." -ForegroundColor Green
                Enable-ScheduledTask -TaskName $TaskName -ErrorAction Stop
                Write-Host "Scheduled task '$TaskName' has been enabled." -ForegroundColor Green
            } else {
                Write-Host "Scheduled task '$TaskName' is already enabled." -ForegroundColor Yellow
            }
            
            $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($TaskInfo -and $TaskInfo.LastTaskResult -ne 267009) {
                Write-Host "Starting scheduled task '$TaskName'..." -ForegroundColor Cyan
                Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            }
            
            Write-Host "Automatic login is now active." -ForegroundColor Green
        } else {
            Write-Host "No scheduled task named '$TaskName' found." -ForegroundColor Red
            Write-Host "Run the installer (install.ps1) to create the scheduled task first." -ForegroundColor Yellow
            Write-Host "Example: .\install.ps1" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Error managing scheduled task: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    exit 0
}

if ($Stop) {
    $TaskName = "llogin"
    
    try {
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Write-Host "Found scheduled task '$TaskName'. Current state: $($ExistingTask.State)" -ForegroundColor Cyan
            
            $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($TaskInfo -and $TaskInfo.LastTaskResult -eq 267009) {
                Write-Host "Stopping running task '$TaskName'..." -ForegroundColor Yellow
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            }
            
            if ($ExistingTask.State -ne "Disabled") {
                Write-Host "Disabling scheduled task '$TaskName'..." -ForegroundColor Yellow
                Disable-ScheduledTask -TaskName $TaskName -ErrorAction Stop
                Write-Host "Scheduled task '$TaskName' has been disabled." -ForegroundColor Green
            } else {
                Write-Host "Scheduled task '$TaskName' is already disabled." -ForegroundColor Yellow
            }
            
            Write-Host "Automatic login has been stopped." -ForegroundColor Green
            Write-Host "To re-enable, run: llogin -Start" -ForegroundColor Cyan
        } else {
            Write-Host "No scheduled task named '$TaskName' found." -ForegroundColor Yellow
            Write-Host "Nothing to stop." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Error managing scheduled task: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    exit 0
}

$LoginUrl = "https://10.10.0.1/24online/servlet/E24onlineHTTPClient"
$LogoutUrl = "https://10.10.0.1/24online/servlet/E24onlineHTTPClient"
$SuccessMessage = "To start surfing"
$SuccessIndicators = @(
    'successfully logged off',
    'You have successfully logged off'
)
$LoginPageIndicator = 'To start surfing'

$CredentialsPath = if ($PSScriptRoot) { 
    Join-Path $PSScriptRoot "credentials.json" 
} else { 
    Join-Path $env:LOCALAPPDATA "Programs\llogin\credentials.json" 
}

function Get-CredentialsFilePath {
    return $CredentialsPath
}

function Get-StoredCredentials {
    try {
        if (Test-Path $CredentialsPath) {
            $json = Get-Content -Path $CredentialsPath -Raw | ConvertFrom-Json
            return @{
                Username = $json.defaultUsername
                Password = $json.defaultPassword
            }
        }
    } catch {
        Write-ColorOutput "Warning: Could not read credentials file: $($_.Exception.Message)" Yellow
    }
    return $null
}

function Set-StoredCredentials {
    param(
        [string]$Username,
        [string]$Password
    )
    
    try {
        $credentialsDir = Split-Path $CredentialsPath -Parent
        if (-not (Test-Path $credentialsDir)) {
            New-Item -ItemType Directory -Path $credentialsDir -Force | Out-Null
        }
        
        $credentialObject = @{
            defaultUsername = $Username
            defaultPassword = $Password
        }
        
        $credentialObject | ConvertTo-Json | Out-File -FilePath $CredentialsPath -Encoding UTF8
        
        Write-ColorOutput "Credentials stored successfully." Green
        Write-LogEntry -Username $Username -Action "Credentials" -Status "updated"
        return $true
    } catch {
        Write-ColorOutput "Error storing credentials: $($_.Exception.Message)" Red
        return $false
    }
}

function Remove-StoredCredentials {
    try {
        if (Test-Path $CredentialsPath) {
            Remove-Item -Path $CredentialsPath -Force
            Write-ColorOutput "Stored credentials removed." Green
            Write-LogEntry -Username "system" -Action "Credentials" -Status "cleared"
        } else {
            Write-ColorOutput "No stored credentials found." Yellow
        }
        return $true
    } catch {
        Write-ColorOutput "Error removing credentials: $($_.Exception.Message)" Red
        return $false
    }
}

function Get-Credentials {

    if ($Username -and $Password) {
        $effectiveUsername = $Username
        $effectivePassword = $Password
        $source = "command line"
    }
    else {
        $stored = Get-StoredCredentials
        if ($stored -and $stored.Username -and $stored.Password) {
            $effectiveUsername = $stored.Username
            $effectivePassword = $stored.Password
            $source = "stored credentials"
        }
    }
    
    return @{
        Username = $effectiveUsername
        Password = $effectivePassword
        Source = $source
    }
}

if ($SetCreds) {
    if ($Username -and $Password) {
        if (Set-StoredCredentials -Username $Username -Password $Password) {
            exit 0
        } else {
            exit 1
        }
    } else {
        Write-Host "Error: Username and password are required for SetCreds." -ForegroundColor Red
        Write-Host "Usage: llogin -SetCreds <username> <password>" -ForegroundColor Yellow
        exit 1
    }
}

if ($ShowCreds) {

    $stored = Get-StoredCredentials
    if ($stored) {
        Write-Host "Location: $CredentialsPath" -ForegroundColor Gray
        Write-Host "Username: $($stored.Username)" -ForegroundColor White
        Write-Host "Password: $($stored.Password)" -ForegroundColor White
    } else {
        Write-Host "json file empty or does not exist ($CredentialsPath)" -ForegroundColor Yellow
    }
    exit 0
}

if ($ClearCreds) {
    if (Remove-StoredCredentials) {
        exit 0
    } else {
        exit 1
    }
}

function Get-CurrentNetwork {
    try {
        $ConnectedProfile = netsh wlan show interfaces | Select-String "Profile" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        
        if ($ConnectedProfile) {
            if ($ConnectedProfile -match "^(LPU|Block).*") {
                Write-Host "Current Network: $ConnectedProfile" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Current Network: $ConnectedProfile (Not an LPU network)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "Current Network: Not connected" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Current Network: Error detecting network - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-LoginSuccess {
    param([string]$ResponseContent)
    return $ResponseContent -match $SuccessMessage
}

function Test-LogoutSuccess {
    param([string]$Content)
    if ($Content -match $LoginPageIndicator) { return $true }
    foreach ($i in $SuccessIndicators) { if ($Content -match [regex]::Escape($i)) { return $true } }
    return $false
}

function Invoke-Login {
    try {
        Write-ColorOutput "Attempting login with ${Username}..." Cyan
        $FormData = "mode=191&username=${Username}%40lpu.com&password=${Password}"

        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $Response = Invoke-WebRequest -Uri $LoginUrl -Method POST -Body $FormData -SkipCertificateCheck
        } else {
            $Response = Invoke-WebRequest -Uri $LoginUrl -Method POST -Body $FormData 
        }
        
        if (Test-LoginSuccess -ResponseContent $Response.Content) {
            Write-ColorOutput "Login successful." Green
            Write-LogEntry -Username $Username -Action "Login" -Status "success" -Url $LoginUrl
            return $true
        } else {
            Write-ColorOutput "Login failed." Red
            Write-LogEntry -Username $Username -Action "Login" -Status "failed"
            return $false
        }
        
    } catch {
        Write-ColorOutput "Error during login: $($_.Exception.Message)" Red
        Write-LogEntry -Username $Username -Action "Login" -Status "failed"
        return $false
    }
}

function Invoke-Logout {
    param(
        [string]$User
    )
    $FormData = "mode=193&username=${User}%40lpu.com&logout=Logout"
    $CommonHeaders = @{ 
        'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'
        'Accept-Language' = 'en-US,en;q=0.9'
        'Cache-Control' = 'no-cache'
        'Pragma' = 'no-cache'
        'Upgrade-Insecure-Requests' = '1'
    }

    try {
        Write-ColorOutput "Attempting logout for user $User" Cyan
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $resp = Invoke-WebRequest -Uri $LogoutUrl -Method POST -Body $FormData -Headers $CommonHeaders -ContentType 'application/x-www-form-urlencoded' -SkipCertificateCheck -ErrorAction Stop
        } else {
            $resp = Invoke-WebRequest -Uri $LogoutUrl -Method POST -Body $FormData -Headers $CommonHeaders -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
        }
        if (Test-LogoutSuccess -Content $resp.Content) {
            Write-ColorOutput "Logout successful (or already logged out)." Green
            Write-LogEntry -Username $User -Action "Logout" -Status "success" -Url $LogoutUrl
            return $true
        } else {
            Write-ColorOutput "Did not detect logout success in response from $LogoutUrl" Yellow
        }
    } catch {
        Write-ColorOutput "Error contacting 10.10.0.1 : $($_.Exception.Message)" Red
    }

    Write-LogEntry -Username $User -Action "Logout" -Status "failed"
    return $false
}

function Test-InternetConnection {
    try {
        # Check connection to Google DNS
        $TestUrl = "https://1.1.1.1/"
        
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $result = Invoke-WebRequest -Uri $TestUrl -Method Head -TimeoutSec 3 -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop
        } else {
            $result = Invoke-WebRequest -Uri $TestUrl -Method Head -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        }
        if ($result.StatusCode -eq 200) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Write-ConnectionLog {
    param(
        [string]$Message
    )
    
    $LogPath = if ($PSScriptRoot) { 
        Join-Path $PSScriptRoot "check-connection.txt" 
    } else { 
        Join-Path $env:LOCALAPPDATA "Programs\llogin\check-connection.txt" 
    }
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$Timestamp - $Message"
    Add-Content -Path $LogPath -Value $LogMessage
}

function Start-ConnectionMonitor {
    param(
        [string]$Username,
        [string]$Password
    )
    
    Write-ColorOutput "Starting connection monitor..." Cyan
    Write-ColorOutput "Checking connection to 1.1.1.1 every second..." Gray
    Write-ColorOutput "Will attempt login after 3 consecutive failed checks" Gray
    Write-ColorOutput "Press Ctrl+C to stop monitoring" Yellow
    Write-Host ""
    
    $FailedAttempts = 0
    $MaxFailedAttempts = 3
    $IsDisconnected = $false
    $CheckInterval = 1 # seconds
    
    # Log monitoring start
    Write-LogEntry -Username $Username -Action "Monitor" -Status "started"
    Write-ConnectionLog "Monitor started for user: $Username"
    
    while ($true) {
        try {
            $HasConnection = Test-InternetConnection
            $Timestamp = Get-Date -Format 'HH:mm:ss'
            
            if ($HasConnection) {
                if ($IsDisconnected) {
                    Write-ColorOutput "[$Timestamp] Connection restored!" Green
                    Write-LogEntry -Username $Username -Action "Monitor" -Status "connection restored"
                    Write-ConnectionLog "Connection restored to 1.1.1.1"
                    $IsDisconnected = $false
                }
                $FailedAttempts = 0
                Write-Host "[$Timestamp] Connection OK" -ForegroundColor Green -NoNewline
                Write-Host "`r" -NoNewline
            } else {
                $FailedAttempts++
                Write-Host "[$Timestamp] No connection (Attempt $FailedAttempts/$MaxFailedAttempts)" -ForegroundColor Yellow
                Write-ConnectionLog "Connection check failed (Attempt $FailedAttempts/$MaxFailedAttempts) to 1.1.1.1"
                
                if ($FailedAttempts -ge $MaxFailedAttempts -and -not $IsDisconnected) {
                    Write-ColorOutput "[$Timestamp] Connection lost for $MaxFailedAttempts attempts. Attempting login..." Red
                    Write-LogEntry -Username $Username -Action "Monitor" -Status "connection lost - attempting login"
                    Write-ConnectionLog "Connection lost for $MaxFailedAttempts attempts - attempting login"
                    $IsDisconnected = $true
                    
                    # Attempt login until successful
                    $LoginAttempts = 0
                    $MaxLoginAttempts = 10
                    
                    while (-not (Test-InternetConnection) -and $LoginAttempts -lt $MaxLoginAttempts) {
                        $LoginAttempts++
                        Write-ColorOutput "[$Timestamp] Login attempt $LoginAttempts..." Cyan
                        Write-ConnectionLog "Login attempt $LoginAttempts of $MaxLoginAttempts"
                        
                        $LoginResult = Invoke-Login
                        
                        if ($LoginResult) {
                            Write-ColorOutput "[$Timestamp] Login successful. Verifying connection..." Green
                            Write-ConnectionLog "Login successful - verifying connection"
                            Start-Sleep -Seconds 2
                            
                            if (Test-InternetConnection) {
                                Write-ColorOutput "[$Timestamp] Connection verified!" Green
                                Write-ConnectionLog "Connection verified to 1.1.1.1"
                                $IsDisconnected = $false
                                $FailedAttempts = 0
                                break
                            }
                        } else {
                            Write-ConnectionLog "Login attempt $LoginAttempts failed"
                        }
                        
                        # Wait before next login attempt
                        Start-Sleep -Seconds 3
                    }
                    
                    if ($LoginAttempts -ge $MaxLoginAttempts) {
                        Write-ColorOutput "[$Timestamp] Maximum login attempts reached. Continuing to monitor..." Yellow
                        Write-LogEntry -Username $Username -Action "Monitor" -Status "max login attempts reached"
                        Write-ConnectionLog "Maximum login attempts ($MaxLoginAttempts) reached - continuing to monitor"
                    }
                }
            }
            
            # Wait before next check
            Start-Sleep -Seconds $CheckInterval
            
        } catch {
            Write-ColorOutput "Error in monitoring loop: $($_.Exception.Message)" Red
            Write-LogEntry -Username $Username -Action "Monitor" -Status "error - $($_.Exception.Message)"
            Write-ConnectionLog "Error in monitoring loop: $($_.Exception.Message)"
            Start-Sleep -Seconds $CheckInterval
        }
    }
}

if ($Update) {
    $UpdateResult = Invoke-Update
    if ($UpdateResult) {
        exit 0
    } else {
        exit 1
    }
}

if ($Monitor) {
    # Get credentials for monitoring mode
    $credentials = Get-Credentials
    $MonitorUsername = $credentials.Username
    $MonitorPassword = $credentials.Password

    if (-not $MonitorUsername -or -not $MonitorPassword) {
        Write-Host "Error: Username and password are required for monitoring mode." -ForegroundColor Red
        Write-Host "Usage: llogin -Monitor <username> <password>" -ForegroundColor Yellow
        Write-Host "   or: Use llogin -SetCreds to store credentials first" -ForegroundColor Yellow
        exit 1
    }
    
    # Check if on LPU network
    if (-not (Get-CurrentNetwork)) {
        Write-Host "Warning: Not connected to LPU network. Monitoring will continue anyway..." -ForegroundColor Yellow
    }
    
    # Start monitoring (this will run indefinitely)
    Start-ConnectionMonitor -Username $MonitorUsername -Password $MonitorPassword
    exit 0
}

if (-not (Get-CurrentNetwork)) {
    exit 1
}

if ($Logout) {
    $Username = Get-LoggedInUser
        $LogoutResult = Invoke-Logout -User $Username
    if ($LogoutResult) {
        exit 0
    } else {
        pause
        exit 1
    }
}

# I had to, it felt wrong having it not under a if statement given how I wrote the entire logic
if ($true) {
    $credentials = Get-Credentials
    $Username = $credentials.Username
    $Password = $credentials.Password

    if (-not $Username -or -not $Password) {
        Write-Host "Error: Username and password are required." -ForegroundColor Red
        Write-Host "Usage: llogin <username> <password>" -ForegroundColor Yellow
        Write-Host "   or: Use llogin -SetCreds to store credentials" -ForegroundColor Yellow
        exit 1
    }
    $LoginResult = Invoke-Login

    if ($LoginResult) {
        exit 0
    } else {
        pause
        exit 1
    }
}



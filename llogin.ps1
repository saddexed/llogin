param(
    [string]$Username,
    [string]$Password,
    [switch]$Help,
    [switch]$Stop,
    [switch]$Start,
    [switch]$Logout,
    [switch]$SaveResponseHtml,
    [switch]$SetCredentials,
    [switch]$PromptCredentials,
    [switch]$ShowCredentials,
    [switch]$ClearCredentials
)

# Utility functions (must be defined before use)
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

if ($Help) {
    Write-Host "LLogin - LPU Wireless Auto Login" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  llogin <username> <password>    Login with specified credentials" -ForegroundColor White
    Write-Host "  llogin                          Login with stored/default credentials" -ForegroundColor White
    Write-Host "  llogin -Logout <username>       Logout the specified user" -ForegroundColor White
    Write-Host "  llogin -SetCredentials          Store default credentials" -ForegroundColor White
    Write-Host "  llogin -PromptCredentials       Set credentials interactively" -ForegroundColor White
    Write-Host "  llogin -ShowCredentials         Show current credential status" -ForegroundColor White
    Write-Host "  llogin -ClearCredentials        Remove stored credentials" -ForegroundColor White
    Write-Host "  llogin -Help                    Show this help message" -ForegroundColor White
    Write-Host "  llogin -Stop                    Stop and disable the scheduled task" -ForegroundColor White
    Write-Host "  llogin -Start                   Start and enable the scheduled task" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  llogin myusername mypassword     Login with your credentials" -ForegroundColor Gray
    Write-Host "  llogin                           Login with stored credentials" -ForegroundColor Gray
    Write-Host "  llogin -SetCredentials john.doe  Store credentials for john.doe" -ForegroundColor Gray
    Write-Host "  llogin -PromptCredentials        Interactive credential setup" -ForegroundColor Gray
    Write-Host "  llogin -Logout john.doe          Logout john.doe" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Credential Priority:" -ForegroundColor Yellow
    Write-Host "1. Command line parameters" -ForegroundColor Gray
    Write-Host "2. JSON credentials file" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor Yellow
    Write-Host "- Must be connected to LPU or Block wireless network" -ForegroundColor Gray
    Write-Host "- Credentials stored securely in JSON format" -ForegroundColor Gray
    exit 0
}

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if ($Start) {
    $TaskName = "llogin"

    if (-not $IsAdmin) {
        Write-Host "Administrator privileges required to manage scheduled tasks." -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        exit 1
    }
    
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
            
            # Try to start the task if it's not running
            $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($TaskInfo -and $TaskInfo.LastTaskResult -ne 267009) {  # 267009 = Currently running
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
    
    if (-not $IsAdmin) {
        Write-Host "Administrator privileges required to manage scheduled tasks." -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Write-Host "Found scheduled task '$TaskName'. Current state: $($ExistingTask.State)" -ForegroundColor Cyan
            
            # Stop the task if it's currently running
            $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($TaskInfo -and $TaskInfo.LastTaskResult -eq 267009) {  # 267009 = Currently running
                Write-Host "Stopping running task '$TaskName'..." -ForegroundColor Yellow
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            }
            
            # Disable the task
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

$Url = "https://10.10.0.1/24online/servlet/E24onlineHTTPClient"
$SuccessMessage = "To start surfing"
$SuccessIndicators = @(
    'successfully logged off',
    'You have successfully logged off'
)
$LoginPageIndicator = 'To start surfing'

# Get credentials file path
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

function Get-EffectiveCredentials {
    $effectiveUsername = $null
    $effectivePassword = $null
    $source = "none"
    
    # Priority 1: Command line parameters
    if ($Username -and $Password) {
        $effectiveUsername = $Username
        $effectivePassword = $Password
        $source = "command line"
    }
    # Priority 2: Stored credentials
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

# Handle credential management parameters
if ($SetCredentials) {
    if ($Username -and $Password) {
        if (Set-StoredCredentials -Username $Username -Password $Password) {
            exit 0
        } else {
            exit 1
        }
    } else {
        Write-Host "Error: Username and password are required for SetCredentials." -ForegroundColor Red
        Write-Host "Usage: llogin -SetCredentials <username> <password>" -ForegroundColor Yellow
        exit 1
    }
}

if ($PromptCredentials) {
    Write-Host "Interactive Credential Setup" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    $promptUser = Read-Host "Enter username"
    if (-not $promptUser) {
        Write-Host "Error: Username cannot be empty." -ForegroundColor Red
        exit 1
    }
    
    $promptPass = Read-Host "Enter password" -AsSecureString
    $promptPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($promptPass))
    
    if (-not $promptPassPlain) {
        Write-Host "Error: Password cannot be empty." -ForegroundColor Red
        exit 1
    }
    
    if (Set-StoredCredentials -Username $promptUser -Password $promptPassPlain) {
        exit 0
    } else {
        exit 1
    }
}

if ($ShowCredentials) {
    Write-Host "Credential Status" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host ""
    
    $stored = Get-StoredCredentials
    if ($stored) {
        Write-Host "JSON Credentials File: Found" -ForegroundColor Green
        Write-Host "  Location: $CredentialsPath" -ForegroundColor Gray
        Write-Host "  Username: $($stored.Username)" -ForegroundColor White
        Write-Host "  Password: [Protected]" -ForegroundColor White
    } else {
        Write-Host "JSON Credentials File: Not found" -ForegroundColor Yellow
        Write-Host "  Expected location: $CredentialsPath" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Current credential priority order:" -ForegroundColor Yellow
    Write-Host "1. Command line parameters (llogin username password)" -ForegroundColor Gray
    Write-Host "2. JSON credentials file" -ForegroundColor Gray
    
    exit 0
}

if ($ClearCredentials) {
    if (Remove-StoredCredentials) {
        exit 0
    } else {
        exit 1
    }
}

# Handle logout parameter validation
if ($Logout -and -not $Username) {
    Write-Host "Error: Username is required for logout." -ForegroundColor Red
    Write-Host "Usage: llogin -Logout <username>" -ForegroundColor Yellow
    exit 1
}

# Skip password requirement for logout
if (-not $Logout) {
    $credentials = Get-EffectiveCredentials
    $Username = $credentials.Username
    $Password = $credentials.Password

    if (-not $Username -or -not $Password) {
        Write-Host "Error: Username and password are required." -ForegroundColor Red
        Write-Host "Usage: llogin <username> <password>" -ForegroundColor Yellow
        Write-Host "   or: Use llogin -SetCredentials to store credentials in JSON file" -ForegroundColor Yellow
        exit 1
    }
}

function Get-CurrentWiFiNetwork {
    try {
        $ConnectedProfile = netsh wlan show interfaces | Select-String "Profile" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }

        if ($ConnectedProfile) {
            return $ConnectedProfile
        } else {
            return $null
        }
    } catch {
        Write-Host "Error getting WiFi network: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Test-LPUNetwork {
    param([string]$NetworkName)
    
    if (-not $NetworkName) {
        return $false
    }
    
    return $NetworkName -match "^(LPU|Block).*"
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
            $Response = Invoke-WebRequest -Uri $Url -Method POST -Body $FormData -SkipCertificateCheck
        } else {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $Response = Invoke-WebRequest -Uri $Url -Method POST -Body $FormData 
        }
        
        if (Test-LoginSuccess -ResponseContent $Response.Content) {
            Write-ColorOutput "Login successful." Green
            Write-LogEntry -Username $Username -Action "Login" -Status "success" -Url $Url
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
        [string]$User,
        [switch]$SaveResponseHtml
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
            $resp = Invoke-WebRequest -Uri $Url -Method POST -Body $FormData -Headers $CommonHeaders -ContentType 'application/x-www-form-urlencoded' -SkipCertificateCheck -ErrorAction Stop
        } else {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $resp = Invoke-WebRequest -Uri $Url -Method POST -Body $FormData -Headers $CommonHeaders -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
        }
        if (Test-LogoutSuccess -Content $resp.Content) {
            Write-ColorOutput "Logout successful (or already logged out)." Green
            Write-LogEntry -Username $User -Action "Logout" -Status "success" -Url $Url
            return $true
        } else {
            Write-ColorOutput "Did not detect logout success in response from $Url" Yellow
            if ($SaveResponseHtml) { $resp.Content | Out-File -FilePath 'response.html' -Encoding UTF8 }
        }
    } catch {
        Write-ColorOutput "Error contacting 10.10.0.1 : $($_.Exception.Message)" Red
    }

    Write-LogEntry -Username $User -Action "Logout" -Status "failed"
    return $false
}

$CurrentNetwork = Get-CurrentWiFiNetwork
Write-Host "Current network: $CurrentNetwork" -ForegroundColor Yellow

if (-not (Test-LPUNetwork -NetworkName $CurrentNetwork)) {
    Write-Host "Not connected to an LPU network. Exiting." -ForegroundColor Red
    exit 1
}

if ($Logout) {
    Write-Host "Connected to LPU network. Proceeding with logout..." -ForegroundColor Green
    $LogoutResult = Invoke-Logout -User $Username -SaveResponseHtml:$SaveResponseHtml

    if ($LogoutResult) {
        exit 0
    } else {
        pause
        exit 1
    }
}

Write-Host "Connected to LPU network. Proceeding with login..." -ForegroundColor Green

$LoginResult = Invoke-Login

if ($LoginResult) {
    exit 0
} else {
    pause
    exit 1
}



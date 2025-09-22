param(
    [string]$Username,
    [string]$Password,
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "LLogin - LPU Wireless Auto Login" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  llogin                          Login with default credentials (if set)" -ForegroundColor White
    Write-Host "  llogin <username> <password>    Login with specified credentials" -ForegroundColor White
    Write-Host "  llogin -Help                    Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  llogin 26667 26667              Login with username 26667" -ForegroundColor Gray
    Write-Host "  llogin john.doe mypassword       Login with custom credentials" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor Yellow
    Write-Host "- Must be connected to LPU or Block wireless network" -ForegroundColor Gray
    Write-Host "- Default credentials can be set in the script file" -ForegroundColor Gray
    exit 0
}

$DefaultUsername = ""
$DefaultPassword = ""
$LoginUrl = "https://10.10.0.1/24online/servlet/E24onlineHTTPClient"
$SuccessMessage = "To start surfing"

if (-not $Username) {
    $Username = $DefaultUsername
}
if (-not $Password) {
    $Password = $DefaultPassword
}

if (-not $Username -or -not $Password) {
    Write-Host "Error: Username and password are required." -ForegroundColor Red
    Write-Host "Usage: llogin <username> <password>" -ForegroundColor Yellow
    Write-Host "   or: Set default credentials in the script file" -ForegroundColor Yellow
    exit 1
}

function Get-CurrentWiFiNetwork {
    try {
        $WifiInfo = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
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

function Invoke-Login {
    try {
        Write-Host "Attempting login with ${Username}..." -ForegroundColor Cyan
        $FormData = "mode=191&username=${Username}%40lpu.com&password=${Password}"

        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $Response = Invoke-WebRequest -Uri $LoginUrl -Method POST -Body $FormData -SkipCertificateCheck
        } else {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $Response = Invoke-WebRequest -Uri $LoginUrl -Method POST -Body $FormData 
        }
        
        if (Test-LoginSuccess -ResponseContent $Response.Content) {
            Write-Host "Login successful." -ForegroundColor Green
            return $true
        } else {
            Write-Host "Login failed." -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host "Error during login: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

$CurrentNetwork = Get-CurrentWiFiNetwork
Write-Host "Current network: $CurrentNetwork" -ForegroundColor Yellow

if (-not (Test-LPUNetwork -NetworkName $CurrentNetwork)) {
    Write-Host "Not connected to an LPU network. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Connected to LPU network. Proceeding with login..." -ForegroundColor Green

$LoginResult = Invoke-Login

if ($LoginResult) {
    exit 0
} else {
    pause
    exit 1
}



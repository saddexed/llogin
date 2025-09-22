# Static Configuration
$Username = "26775"
$Password = "26775"
$LoginUrl = "https://10.10.0.1/24online/servlet/E24onlineHTTPClient"
$SuccessMessage = "To start surfing"

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
        Write-Host "Attempting login..." -ForegroundColor Cyan
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



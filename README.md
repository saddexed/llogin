# LLogin

Automatic login utility for LPU wireless networks.

## Overview

LLogin automatically authenticates with LPU wireless networks when you connect. It detects LPU/Block networks and submits login credentials to the captive portal.

## Features

- Automatic detection of LPU wireless networks
- Scheduled task for automatic login on network connection
- Manual login capability
- Desktop shortcut creation
- Windows event-triggered execution

## Installation

1. Run the installer as administrator:
   ```powershell
   .\install.ps1
   ```

2. Configure your credentials in the installed script:
   - Edit `%USERPROFILE%\llogin.ps1`
   - Update the `$Username` and `$Password` variables

### Installation Options

- `install.ps1` - Full installation with scheduled task
- `install.ps1 -InstallOnly` - Install script only, no scheduler
- `install.ps1 -CreateShortcut` - Include desktop shortcut

## Usage

### Automatic
Once installed, the script runs automatically when you connect to LPU networks.

### Manual
Run the login script directly:
```powershell
& "$env:USERPROFILE\llogin.ps1"
```

Or use the desktop shortcut if created during installation.

## Configuration

Edit the credentials in `llogin.ps1`:
```powershell
$Username = "your_username"
$Password = "your_password"
```

## Requirements

- Windows PowerShell or PowerShell Core
- Administrator privileges (for scheduled task setup)
- Connection to LPU or Block wireless networks

## How It Works

1. Detects current wireless network
2. Checks if connected to LPU/Block network
3. Submits authentication request to `10.10.0.1/24online/servlet/E24onlineHTTPClient`
4. Verifies successful login response

## Management

View scheduled task:
```powershell
Get-ScheduledTask -TaskName "llogin"
```

Run task manually:
```powershell
Start-ScheduledTask -TaskName "llogin"
```

Remove scheduled task:
```powershell
Unregister-ScheduledTask -TaskName "llogin"
```

## File Structure

- `llogin.ps1` - Main login script
- `install.ps1` - Installation and setup script
- `test/` - Test scripts and utilities

## Notes

- The script only activates on LPU or Block wireless networks
- Requires network connectivity to reach the authentication portal
- Uses Windows event triggers for automatic execution

## TODO
- Credential management
- Logout function

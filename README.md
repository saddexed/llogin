# LLogin

Automatic login utility for LPU wireless networks.

## Overview

LLogin automatically authenticates with LPU wireless networks when you connect. It detects LPU/Block networks and submits login credentials to the captive portal.

## Features

- Automatic detection of LPU wireless networks
- Command-line argument support for credentials
- Scheduled task for automatic login on network connection
- Manual login capability
- Desktop shortcut creation
- Windows event-triggered execution
- Cross-platform PowerShell and CMD support

## Installation

### One-Line Installation (Recommended)
Install directly from GitHub:
```powershell
irm https://raw.githubusercontent.com/saddexed/llogin/master/install.ps1 | iex
```

### Local Installation
1. Clone or download the repository
2. Run the installer:
   ```powershell
   .\install.ps1
   ```

### Installation Options

- `install.ps1` - Full installation with scheduled task
- `install.ps1 -InstallOnly` - Install script only, no scheduler
- `install.ps1 -CreateShortcut` - Include desktop shortcut

## Usage

### Command Line Arguments
```powershell
llogin username password    # Login with specific credentials
llogin                      # Use default credentials (if set)
llogin -Help               # Show help message
llogin -Start              # Start and enable scheduled task
llogin -Stop               # Stop and disable scheduled task
```

### Automatic Login
Once installed with the scheduled task, the script runs automatically when you connect to LPU networks.

## Configuration

You can set default credentials in the script file for passwordless usage:

Edit `%LOCALAPPDATA%\Programs\llogin\llogin.ps1`:
```powershell
$DefaultUsername = "your_username"
$DefaultPassword = "your_password"
```

Then simply run `llogin` without arguments.

## Requirements

- Windows PowerShell 5.1 or PowerShell Core 6+
- Administrator privileges (for scheduled task setup only)
- Connection to LPU or Block wireless networks
- Internet connectivity to reach authentication portal

## How It Works

1. Detects current wireless network
2. Checks if connected to LPU/Block network
3. Submits authentication request to `10.10.0.1/24online/servlet/E24onlineHTTPClient`
4. Verifies successful login response

## Task Management

The script includes built-in task management:

```powershell
llogin -Start    # Enable automatic login
llogin -Stop     # Disable automatic login
```

Or use PowerShell commands directly:
```powershell
Get-ScheduledTask -TaskName "llogin"           # View task
Start-ScheduledTask -TaskName "llogin"         # Run task manually
Unregister-ScheduledTask -TaskName "llogin"    # Remove task completely
```

## Installation Directory

Files are installed to: `%LOCALAPPDATA%\Programs\llogin\`
- `llogin.ps1` - Main login script
- `llogin.cmd` - CMD batch wrapper

This directory is automatically added to your PATH for global access.

## Notes

- The script only activates on LPU or Block wireless networks
- Requires network connectivity to reach the authentication portal
- Uses Windows event triggers for automatic execution
- Compatible with both PowerShell and CMD terminals
- No need to distribute `llogin.cmd` - it's generated during installation

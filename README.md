# LLogin - LPU Wireless Auto Login

A PowerShell-based automatic login tool for LPU (Lovely Professional University) wireless networks. For exe versions/Mac and Linux releases, hop over to 

## Installation

### Quick Install
```powershell
# Default
.\install.ps1
# Install with desktop shortcut
.\install.ps1 -CreateShortcut
# Install files only (No task, for manual updates and such)
.\install.ps1 -InstallOnly
```
## Configuration

### Setting Up Credentials

After installation, you can store your credentials securely:
```powershell
# Set your default credentials (recommended)
llogin -set username password
# Or create/edit the credentials file manually
notepad "$env:LOCALAPPDATA\Programs\llogin\credentials.json"
```
The credentials are stored in JSON format at: `%LOCALAPPDATA%\Programs\llogin\credentials.json`
Example credentials.json:
```json
{
    "defaultUsername": "your.username",
    "defaultPassword": "your.password",
}
```

## Usage

### Basic Login Commands

```powershell
# Login with stored default credentials
llogin
# Login with specified credentials (temporarily)
llogin username password
```

### Credential Management Commands

```powershell
# Set/update default credentials
llogin -set username password
# Show stored credentials
llogin -show
# Clear stored credentials
llogin -clear
```

### Logout Commands
```powershell
llogin -l
```

### Scheduled Task Management

```powershell
# Enable automatic login (requires admin privileges)
llogin -start
# Disable automatic login (requires admin privileges)
llogin -stop
```

## Command Reference

| Command | Description | Admin Required |
|---------|-------------|----------------|
| `llogin` | Login with default/stored credentials | No |
| `llogin -h` | Show help information | No |
| `llogin username password` | Login with specified credentials | No |
| `llogin -set username password` | Store default credentials | No |
| `llogin -show` | Show credential status | No |
| `llogin -clear` | Remove stored credentials | No |
| `llogin -l` | Logout | No |
| `llogin -start` | Enable automatic login task | Yes |
| `llogin -stop` | Disable automatic login task | Yes |

## Credential Storage Priority

The script checks for credentials in this order:
1. **Command line parameters** (`llogin username password`)
2. **json credentials file** (`%LOCALAPPDATA%\Programs\llogin\credentials.json`)

## To-Do
- Multi User Cred management
- Powershell 5.1 logout compatibility fix
- Linux/Mac port (proably never, check out [Ba3a's Version](https://github.com/Ba3a-G/LPU-Wireless-Autologin))
- Add logout command and alias
- Inbuilt update option
- ~~Automatic Privilege Escalation for Task Scheduler changes~~

## License
This project is provided as-is for educational and personal use at LPU.

**Note**: This tool is specifically designed for LPU wireless networks and may not work on other captive portal systems.
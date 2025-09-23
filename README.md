# LLogin - LPU Wireless Auto Login

A PowerShell-based automatic login tool for LPU (Lovely Professional University) wireless networks.

## Features

-  Automatic login to LPU/Block wireless networks
-  Manual login with custom credentials
-  Logout functionality for any user
-  Scheduled task management for automatic login
-  **Secure JSON-based credential storage**
-  Activity logging with timestamps
-  Network validation (only works on LPU networks)
-  Cross-platform PowerShell support (Windows PowerShell 5.1 and PowerShell 7+)

## Installation

### Quick Install
```powershell
# Clone or download the repository
# Run the installer (requires admin privileges for scheduled tasks)
.\install.ps1
```

### Installation Options
```powershell
# Install with desktop shortcut
.\install.ps1 -CreateShortcut
```
```powershell
# Install files only (no scheduled task setup)
.\install.ps1 -InstallOnly
```

The installer will:
- Copy `llogin.ps1` to `%LOCALAPPDATA%\Programs\llogin\`
- Add the installation directory to your PATH
- Create PowerShell aliases
- Set up a scheduled task for automatic login (requires admin)
- Optionally create a desktop shortcut

## Configuration

### Setting Up Credentials

After installation, you can store your credentials securely:

```powershell
# Set your default credentials (recommended)
llogin -SetCredentials username password

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

# Login with environment variables
$env:LLOGIN_USERNAME = "user"; $env:LLOGIN_PASSWORD = "pass"; llogin

# Examples
llogin john.doe mypassword
llogin student.name secretpass
```

### Credential Management Commands

```powershell
# Set/update default credentials
llogin -SetCredentials username password

# Prompt for credentials interactively (passwords hidden)
llogin -PromptCredentials

# Show current credential status (without revealing passwords)
llogin -ShowCredentials

# Clear stored credentials
llogin -ClearCredentials
```

### Logout Commands

```powershell
# Logout a specific user
llogin -Logout username

# Logout with response debugging
llogin -Logout username -SaveResponseHtml

# Examples
llogin -Logout john.doe
llogin -Logout student.name
```

### Scheduled Task Management

```powershell
# Enable automatic login (requires admin privileges)
llogin -Start

# Disable automatic login (requires admin privileges)
llogin -Stop

# Check if you're admin before running
# Right-click PowerShell → "Run as Administrator"
```

### Help and Information

```powershell
# Show help message with all available options
llogin -Help
```

## Command Reference

| Command | Description | Admin Required |
|---------|-------------|----------------|
| `llogin` | Login with default/stored credentials | No |
| `llogin username password` | Login with specified credentials | No |
| `llogin -SetCredentials user pass` | Store default credentials | No |
| `llogin -PromptCredentials` | Set credentials interactively | No |
| `llogin -ShowCredentials` | Show credential status | No |
| `llogin -ClearCredentials` | Remove stored credentials | No |
| `llogin -Logout username` | Logout specified user | No |
| `llogin -Start` | Enable automatic login task | Yes |
| `llogin -Stop` | Disable automatic login task | Yes |
| `llogin -Help` | Show help information | No |

## Credential Storage Priority

The script checks for credentials in this order:
1. **Command line parameters** (`llogin username password`)
2. **Environment variables** (`$env:LLOGIN_USERNAME`, `$env:LLOGIN_PASSWORD`)
3. **JSON credentials file** (`%LOCALAPPDATA%\Programs\llogin\credentials.json`)
4. **Interactive prompt** (if `-PromptCredentials` is used)

## Security Features

- **JSON file storage**: Credentials stored in user's local app data (not in script)
- **Environment variable support**: Most secure for CI/CD and automation
- **Interactive prompts**: Passwords hidden during input
- **No hardcoded credentials**: Script file contains no sensitive data
- **File permissions**: Credentials file accessible only to current user

### Security Best Practices

```powershell
# Most secure: Use environment variables
$env:LLOGIN_USERNAME = "username"
$env:LLOGIN_PASSWORD = "password"

# Good: Use JSON file with proper permissions
llogin -SetCredentials username password

# Avoid: Passing credentials as command line arguments (visible in process list)
# llogin username password  # Use sparingly, only for testing
```

## Network Requirements

- Must be connected to an LPU or Block wireless network
- The script validates network connection before attempting login/logout
- Works with networks matching pattern: `LPU*` or `Block*`

## Logging

All login and logout attempts are logged to `log.txt` in the current directory with timestamps:

```
2025-09-23 14:30:15 - Login success for user: john.doe via https://10.10.0.1/24online/servlet/E24onlineHTTPClient
2025-09-23 14:35:22 - Logout success for user: john.doe via https://10.10.0.1/24online/servlet/E24onlineHTTPClient
2025-09-23 14:40:10 - Login failed for user: jane.doe
2025-09-23 14:42:00 - Credentials updated for user: john.doe
```

## Automatic Login Setup

The scheduled task is triggered by network connectivity events and will:
- Automatically detect when you connect to LPU networks
- Run the login script with your default credentials
- Log all attempts for monitoring

### Managing the Scheduled Task

```powershell
# Check task status
Get-ScheduledTask -TaskName "llogin"

# View task details
Get-ScheduledTaskInfo -TaskName "llogin"

# Manual task operations (as admin)
Start-ScheduledTask -TaskName "llogin"
Stop-ScheduledTask -TaskName "llogin"
Enable-ScheduledTask -TaskName "llogin"
Disable-ScheduledTask -TaskName "llogin"
```

## Troubleshooting

### Common Issues

**"Administrator privileges required"**
- Run PowerShell as Administrator for `-Start` and `-Stop` commands
- Right-click PowerShell → "Run as Administrator"

**"No scheduled task found"**
- Run the installer first: `.\install.ps1`
- The installer creates the scheduled task

**"Not connected to an LPU network"**
- Connect to LPU or Block wireless network first
- Script only works on university networks

**"Login failed"**
- Verify your username and password
- Check if you're already logged in
- Try logging out first: `llogin -Logout username`

**"Command not found"**
- Restart your terminal after installation
- Check if installation directory is in PATH
- Try running with full path: `& "$env:LOCALAPPDATA\Programs\llogin\llogin.ps1"`

### Debug Mode

For troubleshooting logout issues:
```powershell
# Save server response for debugging
llogin -Logout username -SaveResponseHtml
# Check response.html file for server messages
```

### Manual Cleanup

To remove the installation:
```powershell
# Remove scheduled task (as admin)
Unregister-ScheduledTask -TaskName "llogin" -Confirm:$false

# Remove installation directory
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Programs\llogin"

# Remove from PATH (manual - edit environment variables)
```

## Technical Details

### Endpoints
- **Login URL**: `https://10.10.0.1/24online/servlet/E24onlineHTTPClient`
- **Logout URL**: `https://10.10.0.1/24online/servlet/E24onlineHTTPClient`

### Login Parameters
- Mode: `191` (login)
- Username format: `username@lpu.com`
- Method: `POST`

### Logout Parameters
- Mode: `193` (logout)
- Username format: `username@lpu.com`
- Method: `POST`

### Success Detection
- **Login success**: Response contains "To start surfing"
- **Logout success**: Response contains "successfully logged off" or returns to login page

## Security Notes

- Credentials are stored in plain text in the script file
- Only use on trusted systems
- Consider using environment variables for sensitive credentials
- The script validates SSL certificates properly

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on LPU networks
5. Submit a pull request

## License

This project is provided as-is for educational and personal use at LPU.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review the log files
3. Test with manual login first
4. Ensure you're on the correct network

---

**Note**: This tool is specifically designed for LPU wireless networks and may not work on other captive portal systems.
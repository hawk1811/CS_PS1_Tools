# CrowdStrike Registry Configuration Script

This PowerShell script manages CrowdStrike proxy configuration settings in the Windows Registry. It allows you to set or update the proxy hostname and port for CrowdStrike services.

## Features

- Configures CrowdStrike proxy settings in the Windows Registry
- Command-line parameters for easy configuration
- Automatic registry path creation if it doesn't exist
- Comprehensive logging of all operations
- Validates and updates existing registry values if they differ from specified values

## Prerequisites

- Windows operating system
- Administrative privileges
- PowerShell 5.1 or higher

## Usage

Run the script with administrative privileges using the following command:

```powershell
.\Set-CrowdStrikeProxy.ps1 -IP "10.50.71.60" -PORT 8443
```

### Parameters

- `-IP`: The proxy hostname or IP address (Required)
- `-PORT`: The proxy port number (Required)

## Logging

The script logs all operations to a file located at:
```
%TEMP%\CS\RegistryLog.txt
```

Each log entry includes a timestamp and details about the operation performed.

## Registry Configuration

The script manages the following registry values under the specified path:
```
HKLM:\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058-48c9-a204-725362b67639}\Default
```

- `CsProxyHostname` (String)
- `CsProxyPort` (DWord)

## Error Handling

The script includes comprehensive error handling and will:
- Create the registry path if it doesn't exist
- Log warnings for non-existent registry values
- Log errors if operations fail
- Continue processing remaining values if one operation fails

## License

This project is licensed under the MIT License - see the LICENSE file for details.

# CrowdStrike Sensor Deployment Check Scripts

A collection of scripts to verify system readiness for CrowdStrike Falcon sensor deployment across Windows, macOS, and Linux platforms.

## Features

- Pre-deployment environment validation
- Certificate and TLS verification
- Connectivity checks for CrowdStrike cloud regions
- Existing sensor detection
- Proxy support
- Multi-region support (US-1, US-2, EU-1)

## Quick Start

### Windows PowerShell

```powershell
# Download and run with specific region
Invoke-WebRequest -Uri 'https://kobigad.com/scripts/Check_Status_Win.txt' -OutFile './Check_Status_Win.ps1'
./Check_Status_Win.ps1 -region 'EU-1'
```

### macOS

```bash
# Download and run with specific region
curl -s https://kobigad.com/scripts/Check_Status_Mac.txt | sed 's/\r$//' | bash -s -- EU-1
```

### Linux

```bash
# Download and run with specific region
curl -s https://kobigad.com/scripts/Check_Status_Lin.txt | sed 's/\r$//' | bash -s -- EU-1
```

## System Requirements

### Windows
- PowerShell 5.1 or later
- Administrative privileges
- TLS 1.2 support
- Required root certificates (DigiCert High Assurance EV Root CA, DigiCert Assured ID Root CA)

### macOS
- Bash shell
- Administrative privileges (sudo access)
- TLS 1.2 support
- System Keychain access

### Linux
- Bash shell
- Root privileges (sudo access)
- TLS 1.2 support
- OpenSSL
- System certificate store access

## Configuration Options

### Windows (Check_Status_Win.ps1)
```powershell
$Config = @{
    CloudRegion = "US-1"                # Default region (US-1, US-2, EU-1)
    UseProxy = $false                   # Enable/disable proxy
    ProxySettings = @{
        Server = ""                     # Proxy server address
        Port = ""                       # Proxy port
        Username = ""                   # Optional proxy username
        Password = ""                   # Optional proxy password
    }
    InstallSensorAfterChecks = $false   # Auto-install after successful checks
    InstallationFilePath = ""           # Path to sensor installer
    InstallationFlags = ""              # Installation flags including CID
}
```

### macOS and Linux
```bash
CLOUD_REGION="US-1"    # Default region (US-1, US-2, EU-1)
USE_PROXY=false        # Enable/disable proxy
PROXY_SERVER=""        # Proxy server address
PROXY_PORT=""          # Proxy port
PROXY_USERNAME=""      # Optional proxy username
PROXY_PASSWORD=""      # Optional proxy password
```

## Checks Performed

1. **Sensor Installation Check**
   - Verifies if the CrowdStrike sensor is already installed
   - Reports CID and AID if sensor is present

2. **TLS Support**
   - Validates TLS 1.2 support
   - Ensures secure communication capability

3. **Root CA Certificates**
   - Checks for required DigiCert root certificates
   - Reports any missing certificates

4. **Cloud Connectivity**
   - Tests connection to region-specific CrowdStrike domains
   - Validates certificate chain and issuer
   - Confirms proper SSL/TLS handshake

## Cloud Regions

The scripts support the following CrowdStrike cloud regions:

- `US-1`: United States (default)
- `US-2`: United States (alternate)
- `EU-1`: European Union

## Output Format

The scripts provide colored output for better visibility:
- ✅ Green: Successful checks
- ❌ Red: Failed checks
- 🔵 Cyan: Section headers and titles

## Error Handling

- Comprehensive error reporting for each check
- Detailed failure messages
- Clear indication of missing requirements
- Certificate validation feedback

## Security Considerations

- Scripts verify SSL/TLS certificate validity
- Proxy support for secured environments
- No sensitive data storage
- Proper error handling for security-related checks

## Troubleshooting

If checks fail, verify:
1. Network connectivity to CrowdStrike domains
2. Proper root certificates installation
3. TLS 1.2 support enablement
4. Proxy configuration (if applicable)
5. Administrative/root privileges

## Contributing

Feel free to submit issues and enhancement requests!

## License

These scripts are released under the MIT License.

## Disclaimer

These scripts are provided as-is, without warranty of any kind. Always test in a non-production environment first.

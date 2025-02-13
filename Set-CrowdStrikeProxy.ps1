param (
    [Parameter(Mandatory=$true)]
    [string]$IP,
    
    [Parameter(Mandatory=$true)]
    [int]$PORT
)

# Define log file path
$logDir = "$env:TEMP\CS"
$logFile = "$logDir\RegistryLog.txt"

# Ensure log directory exists
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Function to log messages
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $logFile
}

# Define registry path and values
$regPath = "HKLM:\SYSTEM\CrowdStrike\{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058-48c9-a204-725362b67639}\Default"
$values = @(
    @{ Name = "CsProxyHostname"; Type = "String"; Value = $IP },
    @{ Name = "CsProxyPort"; Type = "DWord"; Value = $PORT }
)

# Ensure the registry path exists
if (!(Test-Path $regPath)) {
    try {
        New-Item -Path $regPath -Force | Out-Null
        Write-Log "Created registry path: $regPath"
    } catch {
        Write-Log "ERROR: Failed to create registry path $regPath - $_"
        exit 1
    }
}

# Check and set registry values
foreach ($entry in $values) {
    $regName = $entry.Name
    $regType = $entry.Type
    $regValue = $entry.Value
    $existingValue = $null
    
    try {
        $existingValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $regName -ErrorAction SilentlyContinue
    } catch {
        Write-Log "WARNING: Registry value $regName does not exist."
    }
    
    if ($existingValue -ne $regValue) {
        try {
            Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type $regType -Force
            Write-Log "Set registry value: $regName = $regValue ($regType)"
        } catch {
            Write-Log "ERROR: Failed to set $regName = $regValue - $_"
        }
    } else {
        Write-Log "Registry value $regName is already set correctly."
    }
}

Write-Log "Registry check completed."

# CrowdStrike Sensor Deployment Script
# For automation, use this: Invoke-WebRequest -Uri 'https://kobigad.com/scripts/Check_Status_Win.txt' -OutFile './Check_Status_Win.ps1'; & ./Check_Status_Win.ps1 -region 'EU-1';
#######################################################################
# Command-line parameter for CloudRegion
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("EU-1", "US-1", "US-2")]
    [string]$region
)

# Configuration
$Config = @{
    CloudRegion = "US-1"  # Default value, will be overwritten if provided via command-line
    UseProxy = $false     # $true or $false
    ProxySettings = @{
        Server = ""
        Port = ""
        Username = ""		# Optional
        Password = ""		# Optional
    }
    InstallSensorAfterChecks = $false  # $true or $false
    InstallationFilePath = "C:\Path\To\SensorInstaller.exe"
    InstallationFlags = "/install /quiet /norestart CID=<CID_HERE>"
}

# Override CloudRegion if provided via command-line
if ($region) {
    $Config.CloudRegion = $region
}
# Configuration END
#######################################################################

# Script Starts Here
#######################################################################
clear

# Function to print colored and underlined title
function Print-Title {
    param([string]$Title)
    $underline = "=" * $Title.Length
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host $underline -ForegroundColor Cyan
}

# Function to print check result
function Print-CheckResult {
    param(
        [string]$CheckName,
        [bool]$Result,
        [string]$Message = ""
    )
    if ($Result) {
        Write-Host ($CheckName + ": ") -NoNewline
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host ($CheckName + ": ") -NoNewline
        Write-Host "FAILED" -ForegroundColor Red
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Red
        }
    }
}

# Region-specific domains
$RegionDomains = @{
    "EU-1" = @("ts01-lanner-lion.cloudsink.net", "lfodown01-lanner-lion.cloudsink.net")
    "US-1" = @("ts01-b.cloudsink.net", "lfodown01-b.cloudsink.net")
    "US-2" = @("ts01-gyr-maverick.cloudsink.net", "lfodown01-gyr-maverick.cloudsink.net")
}

# Function to check if the sensor is already installed
function Check-SensorInstallation {
    $sensorInfo = @{
        Installed = $false
        CSFalconServiceRunning = $false
        CSAgentServiceRunning = $false
        CID = ""
        AID = ""
    }

    # Check if services exist and are running
    $csfalconService = Get-Service -Name CSFalconService -ErrorAction SilentlyContinue
    $csagentService = Get-Service -Name CSAgent -ErrorAction SilentlyContinue

    if ($csfalconService -and $csagentService) {
        $sensorInfo.Installed = $true
        $sensorInfo.CSFalconServiceRunning = $csfalconService.Status -eq 'Running'
        $sensorInfo.CSAgentServiceRunning = $csagentService.Status -eq 'Running'

        # Check registry for CID and AID
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\CSAgent\Sim"
        if (Test-Path $registryPath) {
            $cidValue = ([System.BitConverter]::ToString(((Get-ItemProperty ("HKLM:\SYSTEM\CurrentControlSet\Services\CSAgent\Sim") -Name CU).CU)).ToLower() -replace '-','')
            $aidValue = ([System.BitConverter]::ToString(((Get-ItemProperty ("HKLM:\SYSTEM\CurrentControlSet\Services\CSAgent\Sim") -Name AG).AG)).ToLower() -replace '-','')

            $sensorInfo.CID = if ($cidValue) { $cidValue.ToString().Trim() } else { "" }
            $sensorInfo.AID = if ($aidValue) { $aidValue.ToString().Trim() } else { "" }
        }
    }

    return $sensorInfo
}

# Function to check TLS 1.2 support
function Test-TLS12Support {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        return $true
    } catch {
        return $false
    }
}

# Function to check for required root CA certificates
function Test-RootCACertificates {
    $requiredCerts = @(
        "CN=DigiCert High Assurance EV Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US",
        "CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US"
    )
    
    $missingCerts = @()
    foreach ($cert in $requiredCerts) {
        if (-not (Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -eq $cert})) {
            $missingCerts += $cert
        }
    }
    
    return $missingCerts
}

# Function to test connectivity and certificate issuer
function Test-ConnectivityAndCertificate {
    param (
        [string]$Domain
    )
    
    $result = @{
        ConnectionSuccess = $false
        CertificateValid = $false
        Issuer = $null
        Message = ""
    }
    
    try {
        $ErrorActionPreference = 'Stop'
        $request = [System.Net.HttpWebRequest]::Create("https://$Domain")
        $request.Timeout = 10000  # Set timeout to 10 seconds
        $request.ServerCertificateValidationCallback = {$true}  # Ignore certificate errors for now
        
        if ($Config.UseProxy) {
            $proxy = New-Object System.Net.WebProxy("http://$($Config.ProxySettings.Server):$($Config.ProxySettings.Port)", $true)
            if ($Config.ProxySettings.Username -and $Config.ProxySettings.Password) {
                $proxy.Credentials = New-Object System.Net.NetworkCredential($Config.ProxySettings.Username, $Config.ProxySettings.Password)
            }
            $request.Proxy = $proxy
        }
        
        $response = $request.GetResponse()
        $result.ConnectionSuccess = $true
        $result.Message = "Connection successful"
        
        # Now check the certificate
        if ($request.ServicePoint.Certificate -ne $null) {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($request.ServicePoint.Certificate)
            $result.Issuer = $cert.Issuer
            
            # Check if the issuer is DigiCert
            if ($cert.Issuer -Like "*CrowdStrike*") {
                $result.CertificateValid = $true
                $result.Message += ". Certificate issuer is valid (CrowdStrike)."
            } else {
                $result.Message += ". Certificate issuer is not valid (expected CrowdStrike)."
            }
        } else {
            $result.Message += ". Unable to retrieve certificate information."
        }
        
        $response.Close()
    }
    catch {
        $result.Message = "Connection failed: $($_.Exception.Message)"
    }
    
    return $result
}

# Function to install the sensor
function Install-Sensor {
    try {
        $process = Start-Process -FilePath $Config.InstallationFilePath -ArgumentList $Config.InstallationFlags -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Sensor installed successfully."
            return $true
        } else {
            Write-Host "Sensor installation failed with exit code: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-Host "Error during sensor installation: $($_.Exception.Message)"
        return $false
    }
}

# Main script execution
Print-Title "CrowdStrike Sensor Deployment Script"
$allChecksPass = $true

# Check if sensor is already installed
$sensorInfo = Check-SensorInstallation
Print-CheckResult "Check if Sensor Installed" $sensorInfo.Installed
if ($sensorInfo.Installed) {
    Print-CheckResult "CSFalconService Status" $sensorInfo.CSFalconServiceRunning
    Print-CheckResult "CSAgent Service Status" $sensorInfo.CSAgentServiceRunning
    Write-Host -NoNewline "CID: " 
    Write-Host $($sensorInfo.CID) -ForegroundColor Green
    Write-Host -NoNewline "AID: "
    Write-Host $($sensorInfo.AID) -ForegroundColor Green
} else {
    $allChecksPass = $false
}

# Check TLS 1.2 support
$tls12Supported = Test-TLS12Support
Print-CheckResult "TLS 1.2 Support" $tls12Supported
if (-not $tls12Supported) {
    $allChecksPass = $false
}

# Check for required root CA certificates
$missingCerts = Test-RootCACertificates
$rootCertsOK = $missingCerts.Count -eq 0
Print-CheckResult "Required Root CA Certificates" $rootCertsOK
if (-not $rootCertsOK) {
    Write-Host "  Missing certificates:"
    $missingCerts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    $allChecksPass = $false
}

# Test connectivity and certificates for region-specific domains
Write-Host "Test Connectivity for Cloud Region:" -NoNewline
Write-Host $Config.CloudRegion -ForegroundColor Green
$domainsToTest = $RegionDomains[$Config.CloudRegion]

foreach ($domain in $domainsToTest) {
    $result = Test-ConnectivityAndCertificate -Domain $domain
    Print-CheckResult "Connection to $domain" $result.ConnectionSuccess $result.Message
    if ($result.ConnectionSuccess) {
        Print-CheckResult "Certificate for $domain" $result.CertificateValid "Issuer: $($result.Issuer)"
    }
    if (-not ($result.ConnectionSuccess -and $result.CertificateValid)) {
        $allChecksPass = $false
    }
}

# Install sensor if all checks pass, installation is requested, and sensor is not already installed
if ($allChecksPass -and $Config.InstallSensorAfterChecks -and -not $sensorInfo.Installed) {
    Write-Host "`nAll checks passed. Proceeding with sensor installation..."
    $installationSuccess = Install-Sensor
    if ($installationSuccess) {
        Write-Host "Sensor deployment completed successfully." -ForegroundColor Green
        $sensorInfo = Check-SensorInstallation  # Update sensor info after installation
    } else {
        Write-Host "Sensor deployment failed." -ForegroundColor Red
    }
} elseif ($sensorInfo.Installed) {
    Write-Host "`nSensor is already installed. Skipping installation."
} elseif (-not $Config.InstallSensorAfterChecks) {
    Write-Host "`nAll checks completed. Sensor installation not requested."
} else {
    Write-Host -F Red "`nSome checks failed." -ForegroundColor Red
}

$endTitle = "Cloud Sensor Deployment Script completed."
$endUnderline = "=" * $endTitle.Length
Write-Host "`n$endTitle" -ForegroundColor Cyan
Write-Host $endUnderline -ForegroundColor Cyan

# Script Ends
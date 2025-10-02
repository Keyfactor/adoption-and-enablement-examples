# KFUtil Utility Script

This repository contains a utility script for interacting with KFUtil, a tool designed to fetch and manage store types and templates.

## Features

- **Environment Configuration**: Easily toggle experimental and debug modes using environment variables.
- **Template Fetching**: Fetch store-type templates seamlessly with a single command.
- **Data Transformation**: Convert JSON outputs into PowerShell objects for streamlined data manipulation.
- **Hash Table Mapping**: Map keys and values into a hash table for easier key-based access.

## Requirements

- **PowerShell**: Ensure you have PowerShell installed on your system.
- KFUTIL.exe installed

## Usage

### Setting Environment Variables

Before running the script, configure the relevant environment variables:

```powershell
$env:KFUTIL_EXP = 0    # Set to 1 to enable experimental mode
$env:KFUTIL_DEBUG = 0  # Set to 1 to enable debug mode
```

### Fetch Templates

Use the script to fetch store-type templates:

```powershell
$list = kfutil store-types templates-fetch
```

### Parse and Process Data

Transform the fetched JSON data into PowerShell objects and store it in a hash table for key-based access:

```powershell
$hashTable = @{}
$list = $list | ConvertFrom-Json
$list.psobject.properties | ForEach-Object {
    $hashTable[$_.Name] = $_.Value
}
```

### Access Keys from Hash Table

Retrieve keys from the hash table:

```powershell
$hashTable.keys
```

### Expected Output

```powershell
F5-CA-REST
VMware-NSX
GCPLoadBal
K8SSecret
K8SJKS
K8SCluster
PaloAlto
Signum
SOS
Fortigate
K8SCert
AlteonLB
GcpCertMgr
AzureAppGw
HCVKVPFX
f5WafTls
```

### Support
This script has no Keyfactor Support and is used as a working example.
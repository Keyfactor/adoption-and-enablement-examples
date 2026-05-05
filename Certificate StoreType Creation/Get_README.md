# get-storetypes.ps1

PowerShell helper script for retrieving available Keyfactor certificate store type templates using `kfutil`.

## Purpose

This script fetches certificate store type templates from a configured Keyfactor environment and outputs the available store type names in sorted order.

It is useful when you need to:

- List available certificate store types
- Confirm which store type templates are available
- Identify valid store type names before creating or configuring certificate stores
- Quickly inspect template availability from the command line

## Prerequisites

Before running this script, ensure the following are available:

- PowerShell
- `kfutil` installed and accessible from your terminal
- `kfutil` configured to connect to the target Keyfactor environment
- Permission to fetch certificate store type templates

## Usage

Run the script from PowerShell:
```powershell
.\get-storetypes.ps1
```

## Expected Output

The script prints a sorted list of available certificate store type names.

Example:
```text
Akamai
AKV
AlteonLB
AppGwBin
AWS-ACM
AWS-ACM-v3
AxisIPCamera
AzureApp
AzureApp2
AzureAppGw
AzureSP
AzureSP2
BoschIPCamera
CiscoAsa
CitrixAdc
DataPower
F5-BigIQ
F5-CA-REST
F5-SL-REST
F5-WS-REST
f5WafCa
f5WafTls
Fortigate
```

## Notes

- The script expects `kfutil` to return JSON output.
- Experimental and debug modes are disabled before fetching templates.
- No credentials or secrets should be stored in this script.
- Run this in a test environment first if you are validating a new configuration.

## Troubleshooting

If the script does not return results:

1. Confirm `kfutil` is installed:
```powershell
kfutil version
```

2. Confirm `kfutil` is authenticated and configured for the correct environment.

3. Verify your account has permission to access store type templates.

4. Run the command manually to inspect the raw response:
```powershell
kfutil store-types templates-fetch
```

## License

Refer to the repository license for usage terms.
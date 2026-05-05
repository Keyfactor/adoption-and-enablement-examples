# How to Use

This script creates one or more Keyfactor certificate store types using `kfutil`.

## Prerequisites

Before running the script, make sure you have:

- PowerShell installed
- `kfutil` installed and available in your system `PATH`
- Access to the target Keyfactor environment
- A valid OAuth client ID, client secret, token URL, scopes, and audience if authentication is required

## Configure the Script

Open the PowerShell script and update the configuration values in the `$Config` section.

Set the Keyfactor host and API path:
```powershell
KEYFACTOR_HOSTNAME = "your-keyfactor-hostname" 
KEYFACTOR_API_PATH = "/KeyfactorAPI"
```

Set your authentication values:
```powershell
KEYFACTOR_AUTH_CLIENT_ID = "<client-id>" 
KEYFACTOR_AUTH_CLIENT_SECRET = "<client-secret>" 
KEYFACTOR_AUTH_TOKEN_URL = "<token-url>" 
KEYFACTOR_AUTH_SCOPES = " " 
KEYFACTOR_AUTH_AUDIENCE = ""
```

Set the store type names you want to create:
```powershell
SelectedStoreType = @("WinSql", "vCenter")
```

To create additional store types, add them to the list:
```powershell
SelectedStoreType = @("WinSql", "vCenter", "CustomStoreType")
```

## Run the Script

From a PowerShell terminal, navigate to the folder containing the script and run:
```powershell
.\post-storetypes.ps1
```

## What the Script Does

The script:

1. Loads the configuration values
2. Sets the required Keyfactor environment variables
3. Reads the selected store type names
4. Runs `kfutil` to create each store type

For each store type, the script runs:
```powershell
kfutil store-types create -n <store-type-name>
```

## Example

If the script is configured with:
```powershell
SelectedStoreType = @("WinSql", "vCenter")
```

Running the script will attempt to create:
```text
WinSql 
vCenter
```

## Troubleshooting

If a store type fails to create, the script will display an error message for that specific store type.

Common things to check:

- `kfutil` is installed and accessible from the terminal
- The Keyfactor hostname is correct
- Authentication values are valid
- The store type name is supported
- Network access to the Keyfactor environment is available

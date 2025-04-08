# Venafi to Keyfactor Command Migration Script

## Overview
The `Venafi_Migration.ps1` script facilitates the migration of certificates from a Venafi environment to a Keyfactor Command environment. It supports multi-threading for efficient processing and includes functionality for environment-specific variable loading, authentication, and certificate retrieval and import.

## Features
- Multi-threaded processing using PowerShell RunspacePools.
- Environment-specific variable loading (Production, NonProduction, Lab, or custom file).
- Authentication with both Venafi and Keyfactor APIs.
- Certificate retrieval from Venafi and import into Keyfactor Command.
- Optional export of private keys along with certificates.
- Configurable logging levels (`Info`, `Debug`, `Verbose`).

## Prerequisites
- PowerShell 5.1 or later.
- Valid client credentials for both Venafi and Keyfactor Command.
- Access to the required APIs with necessary permissions.

## Parameters

| Parameter              | Description                                                                                     | Default Value       |
|------------------------|-------------------------------------------------------------------------------------------------|---------------------|
| `environment_variables` | Specifies the environment from which variables will be pulled. Possible values: `Production`, `NonProduction`, `Lab`, `FromFile`. | None (Mandatory)    |
| `MaxThreads`           | Specifies the maximum number of threads for the RunspacePool.                                   | `10`                |
| `ExportKey`            | Specifies whether to export the private key along with the certificate.                         | `false`             |
| `loglevel`             | Specifies the logging level for console output. Possible values: `Info`, `Debug`, `Verbose`.    | `Info`              |
| `variableFile`         | Specifies the path and file name of the variable file in Hashtable format, if used.             | None (Optional)     |

## Functions

### `load_variables`
Loads environment-specific variables into a hashtable for use throughout the script.

### `Check_KeyfactorStatus`
Validates the connection to the Keyfactor Command API by performing a health check.

### `Check_VenafiStatus`
Validates the connection to the Venafi API by checking the system version.

### `Get-AuthHeaders`
Generates authentication headers for API requests to either Keyfactor or Venafi, depending on the parameters provided.

### `Get-Pem`
Retrieves the PEM-formatted certificate from Venafi for a given Distinguished Name (DN).

### `Get-VenafiCertificates`
Retrieves a list of certificates from Venafi under a specified parent DN.

### `Import-KFCertificate`
Imports a certificate into Keyfactor Command using the provided PEM and thumbprint.

## Usage

### Example 1: Run in Production Environment
```powershell
Venafi_Migration.ps1 -environment_variables Production -MaxThreads 5 -loglevel Debug
```
Runs the script in the Production environment with a maximum of 5 threads and debug-level logging.

### Example 2: Use a Variable File
```powershell
Venafi_Migration.ps1 -environment_variables FromFile -variableFile "C:\path\to\variables.ps1"
```
Runs the script using variables loaded from the specified file logging.

### Example 3: Export Private Keys
```powershell
Venafi_Migration.ps1 -environment_variables FromFile -variableFile "C:\path\to\variables.ps1" -MaxThreads 15 -ExportKey $true -loglevel Debug
```
Runs the script using variables loaded from the specified file with a maximum of 15 threads, debug-level logging, and exporting private keys.

## Notes
- Ensure that the required APIs are accessible and the necessary permissions are granted.
- The script requires valid client credentials for both Keyfactor and Venafi.
- If using a variable file, ensure it is in a valid Hashtable format.

## Output
The script outputs the status of each certificate processed, including success or failure messages for retrieval and import.

## License
This script is provided "as-is" without warranty of any kind. Use at your own risk.

## Author
Jeremy Howland

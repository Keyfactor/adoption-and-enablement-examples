# Owner Update Script for Keyfactor Command

## Overview
The `owner_update.ps1` script is designed to update certificate owners in Keyfactor Command using multithreading. It processes a CSV file containing certificate serial numbers and roles, performs API calls to retrieve and update data, and logs the results for each operation.

## Features
- **Multithreading**: Utilizes PowerShell runspaces to process multiple certificates concurrently.
- **Logging**: Creates individual log files for each certificate processed.
- **API Integration**: Communicates with Keyfactor Command APIs to retrieve and update certificate and role information.
- **Error Handling**: Logs errors for failed operations and provides detailed stack traces.

## Prerequisites
- **PowerShell Version**: Windows PowerShell 5.1 or later.
- **Required Files**:
  - A valid CSV file with the required columns: `serial` and `role`.
  - A variable file containing API credentials and configuration.

## Parameters
| **Parameter**   | **Description**                                                                                     | **Mandatory** | **Default** |
|------------------|-----------------------------------------------------------------------------------------------------|---------------|-------------|
| `csvPath`        | Path to the CSV file containing the data.                                                           | ✅ Yes        | N/A         |
| `maxThreads`     | Maximum number of threads to use for runspaces.                                                     | ✅ Yes        | N/A         |
| `variableFile`   | Path to a file containing a hashtable of variables required for the script (e.g., API credentials). | ✅ Yes        | N/A         |

## CSV File Requirements
The CSV file must include the following columns:
- `serial`: The serial number of the certificate.
- `role`: The role to be assigned as the new owner.

## Usage
### Example 1: Basic Execution
```powershell
owner_update.ps1 -csvPath "C:\data\certificates.csv" -maxThreads 5 -variableFile "C:\config\variables.ps1"
```
Processes the certificates in the specified CSV file using 5 threads and loads variables from the specified file.

## Logging
- Logs are stored in the RunspaceLogs directory within the script's location.
- Each log file is named using the format: log_<serial>.log.
- Logs include timestamps and detailed messages for each operation.

## Functions
Key Functions in the Script:
1. `CreateLogDirectory`: Ensures the log directory exists.
2. `new-logentry`: Writes log entries to a file for each certificate processed.
3. `create_auth`: Generates authentication headers using client credentials.
4. `Invoke-HttpPut`: Sends HTTP PUT requests with authentication headers.
5. `Invoke-HttpGet`: Sends HTTP GET requests with authentication headers.
6. `Check_KeyfactorStatus`: Validates the connection to Keyfactor Command.
7. `Get-Certificates`: Retrieves the certificate ID for a given serial number.
8. `Get-RoleId`: Retrieves the role ID for a given role name.
9. `Update-CertificateOwner`: Updates the owner of a certificate.

## Error Handling
- **Connection Errors**: Logs errors if the connection to Keyfactor Command fails.
- **Certificate Not Found**: Logs an error if a certificate with the specified serial number is not found.
- **Role Not Found**: Logs an error if the specified role does not exist.
- **General Errors**: Logs detailed error messages and stack traces for debugging.

## Example Output
```
[10-04-2025 14:30:00] Validated connection to Keyfactor Command
[10-04-2025 14:30:01] Getting certificate ID for: 1234567890ABCDEF
[10-04-2025 14:30:02] Certificate ID: 12345
[10-04-2025 14:30:03] Getting role ID for: AdminRole
[10-04-2025 14:30:04] Role ID: 67890
[10-04-2025 14:30:05] Updating certificate with New Role owner: AdminRole
[10-04-2025 14:30:06] Owner updated: AdminRole
```

## Notes
- Ensure that the variable file contains valid API credentials and configuration.
- The script measures and displays the total elapsed time for processing all certificates.
- Logs are created for each certificate, making it easier to debug individual operations.

## Links
- [Explination of Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/Owner_Update/Code.md)
- [Example CSV](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/Owner_Update/Sample.CSV)
- [Variable File](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/Owner_Update/Variables.ps1)
- [Keyfactor Command Documentation](https://software.keyfactor.com)
## License
This script is licensed under the MIT License.

---

### Author
© 2025 Keyfactor
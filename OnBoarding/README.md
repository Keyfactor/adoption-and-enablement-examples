# Keyfactor Onboarding Automation Script

## Overview

This PowerShell script automates the creation and management of Keyfactor collections, roles, and permissions. It simplifies onboarding for Keyfactor environments by enabling users to define parameters, manage claims, and assign roles in a structured and reusable way.

---

## Features

- **Dynamic Environment Support**: Supports multiple environments (`Production`, `NonProduction`, `Lab`, or `FromFile`).
- **Role and Collection Management**: Automatically creates roles, collections, and assigns the necessary permissions.
- **Claim Management**: Supports adding claims of types `OAuthRole` and `OAuthSubject`.
- **Customizable Execution**: Users can tailor the script's behavior using optional parameters and switches.
- **Advanced Logging**: Provides detailed logging with adjustable verbosity levels (`Info`, `Debug`, `Verbose`).
- **Error Handling and Debugging**: Includes robust error management to ensure smooth execution.

---

## Prerequisites
To run this script, you need the following:
- Windows PowerShell version 5.1 or later (or PowerShell Core for cross-platform support).
- Appropriate permissions to execute scripts on your system.
- Ensure your execution policy allows running scripts. Use the following command if required:
- Enter all Variable Values under the load_variables function  

---

## Parameters
The script uses the following parameters:

| **Parameter**           | **Description**                                                               | **Default Value**       | **Values**                                        | **Mandatory** |
|-------------------------|-------------------------------------------------------------------------------|-------------------------|---------------------------------------------------|---------------|
| `environment_variables` | Specify the environment for variable retrieval.                               | None (must be provided) | `Production`, `Non-Production`, `Lab`, `FromFile` | ✅ Yes         |
| `role_name`             | Name of the role and collection to be created.                                | None (must be provided) | Custom string                                     | ✅ Yes         |
| `loglevel`              | Configures the level of debug output during the script execution.             | `Info`                  | `Info`, `Debug`, `Verbose`                        | ❌ No          |
| `role_email`            | Email address associated with the role.                                       | `null`                  | Email address format                              | ❌ No          |
| `Claim`                 | Optional parameter to define additional claims for operations.                | `null`                  | Custom string                                     | ❌ No          |
| `Claim_Type`            | Type of claim to be added.                                                    | None                    | `OAuthRole`, `OAuthSubject`                       | ❌ No          |
| `RoleOnly`              | Only create roles without associated claims or collections.                   | None                    | (Switch)                                          | ❌ No          |
| `variableFile`          | Path to a variable file in Hashtable format for loading additional variables. | None                    | (Full path to variable file)                      | ❌ No          |
| `Force`                 | Allows the script to proceed despite validation failures.                     | None                    | (Switch)                                          | ❌ No          |

---

## Variables
The script uses the following variables in the load_variables FUNCTION:

| **Variable**             | **Description**                                                                                                                                                                           | **Default Value**       | **Values**                                            | **Mandatory** |
|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------|-------------------------------------------------------|---------------|
| `CLIENT_ID`              | The Client ID  as provided by the IDP Application.                                                                                                                                        | None (must be provided) | N\A                                                   | ✅ Yes         |
| `CLIENT_SECRET`          | The Secret  as provided by the IDP Application.                                                                                                                                           | None (must be provided) | N\A                                                   | ✅ Yes         |
| `TOKEN_URL`              | The Token URL  as provided by the IDP Application.                                                                                                                                        | None (must be provided) | N\A                                                   | ✅ Yes         |
| `INCLUDE_EMAIL_IN_ROLE`  | If set to $true the name of the Role and the Query in the Collection will be the Team Name plus the Team Email "Team (Team@domain.com)"                                                   | None                    | N\A                                                   | ✅ Yes         |
| `ROLE_PERMISSIONS`       | Specifies list of permissions the role will have.  these permissions are structured based on Keyfactor Permissions that can be found in the Official Documentation for Keyfactor Command. | None                    | N\A                                                   | ✅ Yes         |
| `KEYFACTORAPI`           | The keyfactor API URL. ("https://CUSTOMER.KEYFACORPKI.COM/KEYFACTORAPI")                                                                                                                  | None (must be provided) | N\A                                                   | ✅ Yes         |
| `SCOPE`                  | The Scope as provided by the IDP Application.                                                                                                                                             | None                    | (Only Required if IDP needs it to get a bearer token) | ❌ Dep         |
| `AUDIENCE`               | The audience as provided by the IDP Application.                                                                                                                                          | None                    | (Only Required if IDP needs it to get a bearer token) | ❌ Dep         |
| `CLAIM_SCHEME`           | Specifies name of the OAuth Scheme that the claim will use by. (must be listed in Keyfactor Command)                                                                                      | None                    | (Only Required if using "Claim" parameter)            | ❌ Dep         |
| `ADDITIONAL_COLLECTIONS` | Specifies a list of additional collections to add the Claim value too.                                                                                                                    | None                    | N\A                                                   | ❌ No          |
| `ADDITIONAL_ROLES`       | Specifies a list of additional Roles to add the Claim value too.                                                                                                                          | None                    | N\A                                                   | ❌ No          |
| `COLLECTION_DESCRIPTION` | A description that will be used in the description of the Collection.                                                                                                                     | None                    | N\A                                                   | ❌ No          |
| `ROLE_DESCRIPTION`       | A description that will be used in the description of the role.                                                                                                                           | None                    | N\A                                                   | ❌ No          |
| `CLAIM_DESCRIPTION`      | A description that will be used in the description of the claim.                                                                                                                          | None                    | N\A                                                   | ❌ No          |
---
## Examples

### 1. Basic Execution in Production Environment:
```powershell
.\keyfactor_onboarding.ps1 -environment_variables Production -role_name MyRole -role_email myrole@example.com -Claim MyClaim -Claim_Type OAuthRole
```
Creates a role and collection for `MyRole` in the `Production` environment with the specified claim type.

### 2. Execution with Debug Logging:
```powershell
.\keyfactor_onboarding.ps1 -environment_variables Production -role_name AnotherRole -role_email test@example.com -Claim TestClaim -Claim_Type OAuthRole -loglevel Debug
```
Executes the script with debug-level logs for troubleshooting.

### 3. Role Creation with Minimal Parameters:
```powershell
.\keyfactor_onboarding.ps1 -environment_variables Production -role_name SimpleRole
```
Creates a role and collection for `SimpleRole` and prompts the user for missing details.

### 4. Forcing Execution Without Email:
```powershell
.\keyfactor_onboarding.ps1 -environment_variables Production -role_name NoEmailRole -Force
```
Allows execution without email validation and proceeds with role creation.

### 5. Variables Loaded from a File:
```powershell
.\keyfactor_onboarding.ps1 -environment_variables FromFile -role_name RoleWithVariables -Force -variableFile "C:\Path\To\Variables.ps1"
```
Loads variables from the specified file and creates a role in the `FromFile` environment.

### 6. Run as a Batch:
```powershell
# Description: This script is used to onboard multiple teams in Keyfactor using a CSV file.
# It reads the team names, emails, claims, and claim types from the CSV file and calls the Keyfactor onboarding script for each team.
foreach ($line in Import-Csv -Path $CSV_PATH) {
.\keyfactor_onboarding.ps1 -environment_variables Production -role_name $line.name -role_email $line.email -Claim $line.claim -Claim_Type $line.claimType
}
```

---

## Workflow

### Initial Setup
- Validates required parameters and initializes logging based on the specified level.
- Verifies connectivity with the Keyfactor Command API.

### Main Actions
1. **Collections**: Checks if the collection exists; creates a new one if it doesn't.
2. **Roles**: Creates the specified role and associates it with collections and permissions.
3. **Claims**: Manages and assigns claims to the specified roles.
4. **Additional Roles**: Updates existing roles with specific claims, as referenced.

### Logging
Provides detailed logs for key operations. Levels include:
- `Info`: General operational messages.
- `Debug`: In-depth logging for developers.
- `Verbose`: Highly detailed output for troubleshooting.

---

## Help
The script includes comment-based help documentation. To access it, use the following commands:

- **Get All Help**:
  ```powershell
  Get-Help ./YourScript.ps1
  ```

- **View Detailed Help**:
  ```powershell
  Get-Help ./YourScript.ps1 -Detailed
  ```

- **View Script Examples**:
  ```powershell
  Get-Help ./YourScript.ps1 -Examples
  ```

---

## Requirements

- **PowerShell Version**: The script works with modern PowerShell standards.  
- **Keyfactor Environment**: Ensure valid Keyfactor Command API credentials and URLs are configured in the variables.

---

## Troubleshooting

- **Missing Parameters**: Ensure all required parameters are passed. Use `-Force` to suppress validation checks.
- **API Connection Issues**: Verify that the Keyfactor Command API credentials and URLs are accessible.
- **Debugging**: Utilize the `-loglevel Debug` option to view detailed logs and track issues.
---

## License
This script is licensed under the [MIT License](https://opensource.org/licenses/MIT). You are free to use, modify, and distribute it.

---

## Links
- [Explanation of Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/team_onbording/Code.md)
- [Keyfactor Command Documentation](https://software.keyfactor.com)

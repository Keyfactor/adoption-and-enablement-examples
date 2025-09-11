# RoleNameUpdate.ps1 Script

## Overview

The **RoleNameUpdate.ps1** script automates the process of renaming a Keyfactor role, transferring ownership of certificates, and updating email addresses. It is designed for use across multiple environments (Production, NonProduction, Lab) with detailed logging for easier troubleshooting.

---

## Features

- **Role Renaming**: Allows updating the name of an existing Keyfactor role.
- **Email Address Updates**: Optionally updates the email address for the role.
- **Certificate Ownership Transfer**: Migrates all certificates owned by the old role to the new one.
- **Logging Levels**: Supports adjustable log levels: `Info`, `Debug`, `Verbose`.
- **Multi-Environment Support**: Configurable for `Production`, `NonProduction`, or `Lab` environments.

---

## Requirements

- **API Permissions**: This script should be run with Administrator permissions to ensure it has access to all requires API permissions.
- **Environment Configurations**: Include appropriate client secrets and API endpoints for each environment.
- **PowerShell**: Ensure PowerShell is installed on the executing machine.

---

## Environment Variables

| Parameter        | Type     | Description                                                                    | Required      |
|------------------|----------|--------------------------------------------------------------------------------|---------------|
| `CLIENT_ID`      | String   | OAuth Client Credential Client Id.                                             | Yes           |
| `CLIENT_SECRET`  | String   | OAuth Client Credential Client Secret.                                         | No (Prompted) |
| `TOKEN_URL`      | String   | OAuth Client Credential token URL.                                             | Yes           |
| `SCOPE`          | String   | OAuth Client Credential Scope.                                                 | Yes           |
| `AUDIENCE`       | String   | OAuth Client Credential Audience.                                              | Yes           |
| `KEYFACTORAPI`   | String   | URL to the Keyfactor API URL. (<https://customer.keyfactorpki.com/keyfactorapi>) | Yes           |

---

## Parameters

| Parameter           | Type     | Description                                                                                     | Required | Default  |
|---------------------|----------|-------------------------------------------------------------------------------------------------|----------|----------|
| `-Environment`      | String   | Specifies the environment (Production, NonProduction, Lab).                                     | Yes      |          |
| `-OriginalRoleName` | String   | The name of the existing role that needs renaming.                                              | Yes      |          |
| `-NewRoleName`      | String   | The new name for the role.                                                                      | Yes      |          |
| `-NewRoleEmail`     | String   | (Optional) The new email address of the role.                                                   | No       | ""       |
| `-LogLevel`         | String   | Log output levels: `Info`, `Debug`, or `Verbose`.                                               | No       | Info     |

---

## Usage

**Example:**

```powershell
.\RoleNameUpdate.ps1 -environment "Production" -OriginalRoleName "OldRole" -NewRoleName "NewRole" -NewRoleEmail "newrole@example.com" -loglevel "Verbose"
```

---

## Functions

The script includes several helper functions:

- **`load_variables`**: Loads environment-specific variables for API configurations.
- **`Remove-role`**: Deletes a role based on the name.
- **`Get_Roles`**: Retrieves role details.
- **`update-owner`**: Transfers certificate ownership from one role to another.
- **`Get-Certificates`**: Retrieves certificates owned by a role.
- **`write-message`**: Outputs log messages with timestamps and log levels.
- **`get-AuthHeaders`**: Fetches authentication headers for API requests.
- **`Get_Claims`**: Retrieves claim details based on a claim ID.
- **`Fetch_AllPages`**: Handles paginated API responses.
- **`Build-Claim`**: Constructs a claim object for role updates.
- **`Update-Role`**: Executes the role update, including renaming, email updates, and claim modifications.

---

## Logging

The script supports three log levels:

- **Info**: General operational information.
- **Debug**: Detailed debugging output.
- **Verbose**: Extensive details for each operation.

---

## Notes

1. Use caution when running the script in production environments.
2. Ensure sensitive information such as client secrets is securely managed.
3. The script requires necessary API permissions to modify roles and transfer certificates.

---

## License

This script is provided "as is" without warranty. Use at your own risk.

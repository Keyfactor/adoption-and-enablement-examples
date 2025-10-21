# PowerShell Automation Script for Roles and Claims Management

This repository contains a robust PowerShell script designed for managing **roles, claims**, and **log cleanup** in a secure and efficient manner. It interacts with **Azure AD**, **Keyfactor API**, and local systems to automate tasks like role management, claim creation, and log file cleanup.

---

## Features

### 1. Environment Variables Management

The script uses an `environment` parameter (`Production`, `NonProduction`, `Lab`) to dynamically configure and retrieve variables specific to the environment.

- **Function**: `Get-Variables`
- **Key Features**:
  - Retrieves default and environment-specific variables from predefined mappings.
  - Allows variables like `client_id`, `client_secret`, `KEYFACTORAPI`, and `PermissionSetName`.

---

### 2. Log File Cleanup

Automates the management of log files to ensure efficient disk space usage and compliance.

- **Function**: `Remove-Logs`
- **Key Features**:
  - Deletes log files older than a configurable number of days (`retentiondays`).
  - Supports recursive scanning of the specified log folder.
  - Includes error handling and dry run mode for testing.

---

### 3. Azure AD Integration

Interacts with Azure Active Directory to retrieve group members and their associated metadata.

- **Function**: `Get-EntraGroupTransitiveMembers`
- **Key Features**:
  - Handles token refresh and integrates with Azure Graph API.
  - Retrieves transitive membership of specified Azure AD groups.

---

### 4. Keyfactor Role and Claim Management

Creates, updates, and synchronizes **roles** and **claims** using **Keyfactor Command API**:

- **Function**: `get-roles`, `new-claim`, `New-Role`, `update-role`
- **Key Features**:
  - Reads roles and claims using Keyfactor APIs.
  - Automates creation or updates of roles and claims, ensuring their alignment with the current state.
  - Supports `dryrun` mode for safe testing (no changes are applied).

---

### 5. Logging System

A robust, script-wide logging system ensures transparency and traceability during script execution.

- **Function**: `Write-Message`
- **Key Features**:
  - Supports multiple logging levels (`Info`, `Warning`, `Error`, `Debug`, and `Verbose`).
  - Writes logs to both output console and file system.
  - Customizable logging path based on the current date.

---

## Required Environment Configuration

Some variables are dynamically retrieved based on the environment (`Production`, `NonProduction`, `Lab`). These include:

| Variable               | Description                                                             |
|------------------------|-------------------------------------------------------------------------|
| `entra_client_id`      | Azure AD Client ID for API access.                                      |
| `entra_client_secret`  | Azure AD Client Secret.                                                |
| `entra_token_url`      | URL to obtain OAuth2.0 token for Azure Graph API.                      |
| `client_id`            | Keyfactor Client ID for API integration.                               |
| `client_secret`        | Keyfactor Client Secret for secure access.                             |
| `KEYFACTORAPI`         | URL for the Keyfactor Command API (e.g., `https://example.com`).       |
| `PermissionSetName`    | Target name of the permission set for Keyfactor roles.                 |

---

## Usage Instructions

### Pre-requisites

- Windows PowerShell (5.1) or PowerShell Core (7.x+).
- The necessary API credentials for Azure AD and Keyfactor Command.
  - Azure
    - Group.Read.All (Application and Deligated)
    - GroupMember.Read.All (Application)
  - Keyfactor
    - Should be ran with Admin Level permissions givent he number of API's it uses
- Appropriate access to the target environment.

### Parameters/Variables

| Parameter                  | Description                                             | Default Value |
|----------------------------|---------------------------------------------------------|---------------|
| `$script:environment`      | Target environment (`Production`, `NonProduction`, `Lab`). | `Lab`         |
| `$script:logfolder`        | Directory to store log files.                           | `.\`          |
| `$script:retentiondays`    | Number of days to retain log files.                     | `30`          |
| `$script:dryrun`           | Enable dry-run mode for test execution (`true`/`false`). | `false`       |
| `$script:loglevel`         | Logging verbosity (`Info`, `Debug`, `Verbose`).         | `Info`        |

---

## How to Run the Script

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/yourusername/your-repo.git
   cd your-repo
   ```

2. **Edit Configuration**:
   Update `$script:environment`, `$script:dryrun`, and the environmental credentials as per your requirements.

3. **Run the Script**:

   ```powershell
   .\ScriptName.ps1
   ```

4. **View Logs**:
   Logs will be generated under the specified `$script:logfolder`.

---

## Example Commands

### Retrieve Environment Variables

```powershell
$vars = Get-Variables -environment "Production"
Write-Host "Loaded environment variables:"
$vars
```

### Clean Old Logs

```powershell
Remove-Logs -logfolder "C:\Logs" -retentiondays 15
```

### Create a New Role

```powershell
New-Role -RoleName "TestRole" -Mail "user@example.com" -Claim $claim
```

---

## Error Handling

The script extensively logs all events, including warnings and errors:

- Errors during API interactions are captured and written to both the log and console.
- Detailed exception handling ensures reliability even during unexpected failures.

---

## Support

This is a working example and Keyfactor provides no ongoing support or changes.

## License

This code is licensed under the **MIT License**. For details, see [`LICENSE`](LICENSE).

---

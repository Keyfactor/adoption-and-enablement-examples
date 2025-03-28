# PowerShell Script: Team Configuration and Environment Management

## Overview
This PowerShell script is designed to streamline the process of onboarding teams configurations, claims, and environment-related settings. It provides options to specify the environment (Production or Non-Production), add team details, and handle OAuth-based claims efficiently. The script follows PowerShell best practices, including parameter validation, debugging settings, and detailed help documentation.

---

## Features
- **Environment Support**: Execute the script in either `Production` or `Non-Production` environments.
- **Team Customization**: Configure team names, emails, and additional claims seamlessly.
- **OAuth-Based Claims**: Define and process claims using `OAuthRole` and `OAuthSubject`.
- **Debugging Options**: Set debugging behaviors using `DebugPreference`.
- **PowerShell Best Practices**: Includes comment-based help, parameter validation, and dynamic debugging options.

---

## Prerequisites
To run this script, you need the following:
- Windows PowerShell version 5.1 or later (or PowerShell Core for cross-platform support).
- Appropriate permissions to execute scripts on your system.
- Ensure your execution policy allows running scripts. Use the following command if required:
- Enter all Variable Values under the load_variables function  
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
  ```

---

## Parameters
The script uses the following parameters:

| **Parameter**    | **Description**                                                                 | **Default Value**       | **Values**                   | **Mandatory** |
|-------------------|---------------------------------------------------------------------------------|-------------------------|------------------------------|---------------|
| `enviroment`      | Specifies the environment where the script will run.                           | None (must be provided) | `Production`, `Non-Production` | ✅ Yes        |
| `DebugPreference` | Configures the level of debug output during the script execution.              | `SilentlyContinue`      | `Continue`, `SilentlyContinue` | ❌ No         |
| `team_name`       | The team name for which the configuration or operation is performed.           | None (must be provided) | Custom string                | ✅ Yes        |
| `team_email`      | An optional parameter for specifying the team's email address.                 | `null`                  | Email address format         | ❌ No         |
| `Claim`           | Optional parameter to define additional claims for operations.                | `null`                  | Custom string                | ❌ No         |
| `Claim_Type`      | Specifies the type of OAuth claim for the operation.                          | None                    | `OAuthRole`, `OAuthSubject`  | ❌ No         |

---

## Variables
The script uses the following variables in the load_variables FUNCTION:

| **Variable**    | **Description**                                                                 | **Default Value**       | **Values**                   | **Mandatory** |
|-------------------|---------------------------------------------------------------------------------|-------------------------|------------------------------|---------------|
| `AUTHENTICATION`| Specifies the IDP where the Bearer Tken will be retrieved.| None (must be provided) | `ENTRA`, `PINGONE` | ✅ Yes        |
| `CLIENT_ID` | The Client ID  as provided by the IDP Application.| None (must be provided)| N\A | ✅ Yes |
| `CLIENT_SECRET`| The Secret  as provided by the IDP Application.| None (must be provided)| N\A | ✅ Yes |
| `TOKEN_URL`| The Tken URL  as provided by the IDP Application.| None (must be provided)| N\A | ✅ Yes |
| `SCOPE`| The Scope as provided by the IDP Application.| None (must be provided)| (Only Required if IDP needs it to get a bearer token) | ❌ Dep |
| `AUDIENCE`| The audience as provided by the IDP Application.| None (must be provided)| (Only Required if IDP needs it to get a bearer token) | ❌ Dep |
| `KEYFACTORAPI`| The keyfactor API URL. ("https://CUSTOMER.KEYFACORPKI.COM/KEYFACTORAPI") | None (must be provided)| N\A | ✅ Yes |
| `ADDITIONAL_COLLECTIONS`| Specifies a list of additional collections to add the Claim value too.| None | N\A | ❌ No |
| `ADDITIONAL_ROLES`| Specifies a list of additional Roles to add the Claim value too.| None | N\A | ❌ No |
| `COLLECTION_DESCRIPTION` | A description that will be used in the description of the Collection.| None | N\A | ❌ No |
| `ROLE_DESCRIPTION` | A description that will be used in the description of the role.| None | N\A | ❌ No |
| `CLAIM_SCHEME` | Specifies name of the OAuth Scheme that the claim will use by. (must be listed in Keyfactor Commnad) | None | (Only Required if using "Claim" parameter) | ❌ Dep|
| `CLAIM_DESCRIPTION` | A description that will be used in the description of the claim.| None | N\A | ❌ No |
| `INCLUDE_EMAIL_IN_ROLE`| If set to $true the name of the Role and the Query in the Collection will be the Team Name plus the Team Email "Team (Team@domain.com)"| None | N\A | ✅ Yes |
| `ROLE_PERMISSIONS`| Specifies list of permissions the role will have.  these permissions are structured based on Keyfactor Permissions that can be found in the Official Doumentation for Keyfactor Command.| None | N\A | ✅ Yes |

---
## Usage

### Example 1: Run in Production Environment
```powershell
./YourScript.ps1 -enviroment Production -team_name "FinanceTeam" - Claim "FinanceTeamGroup" -Claim_Type OAuthRole
```
**Description**: Executes the script in `Production` mode for the team `FinanceTeam` with the OAuth claim type set to `OAuthRole`.

---

### Example 2: Run in Non-Production with Debugging
```powershell
./YourScript.ps1 -enviroment Non-Production -DebugPreference Continue -team_name "DevTeam"
```
**Description**: Executes the script in a `Non-Production` environment with debug output set to continuous and for the team `DevTeam`.

---

### Example 3: Run with Claims
```powershell
./YourScript.ps1 -enviroment Production -team_name "HRTeam" -Claim "ManageUsers" -Claim_Type OAuthSubject
```
**Description**: Runs the script in the `Production` environment, adds a custom claim `ManageUsers`, and sets the OAuth claim type to `OAuthSubject`.

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

## Debugging
The script allows you to set `DebugPreference` to control the verbosity of debug logs:
- `Continue`: Displays debug logs during execution.
- `SilentlyContinue` (default): Hides debugging information unless explicitly needed.

---

## Best Practices
- Use a descriptive name for your `team_name` to avoid ambiguity.
- Validate your email address format before providing it to `team_email`.
- Always run the script in the appropriate environment to avoid configuration mismatches.

## Author
- **Name**: Jeremy Howland
- **Version**: 1.0
- **Date**: 2025-03-28

---

## License
This script is licensed under the [MIT License](https://opensource.org/licenses/MIT). You are free to use, modify, and distribute it.

---

## Links
- [Explination of Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/team_onbording/Code.md)
- [PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/)
- [ValidateSet Attribute](https://learn.microsoft.com/en-us/powershell/scripting/samples/validateset)

# ACME Claims Management Script

A PowerShell script for managing ACME claims through a REST API interface. This script provides functionality to add, remove, update, and display claims with role-based access control.

## Features

- Add new claims with specified roles and templates
- Remove existing claims by ID
- Update claim properties
- Display all existing claims
- Environment-specific configuration support (Production, Non-Production, Lab)
- OAuth token-based authentication

## Prerequisites

- PowerShell 5.1 or higher
- Network access to ACME endpoints
- Valid OAuth credentials (Client ID and Secret)
- Keyfactor ACME 25.2.1

## Parameters

| Parameter    | Required | Description                                   | Allowed Values                            |
|-------------|----------|-----------------------------------------------|------------------------------------------|
| ClaimType   | No       | Type of the claim to manage                   | String                                   |
| ClaimValue  | No       | Value associated with the claim               | String                                   |
| Roles       | No       | Roles to assign to the claim                  | AccountAdmin, EnrollmentUser, SuperAdmin |
| action      | Yes      | Action to perform on claims                   | add, remove, update, show                |
| Template    | No       | Template short name associated with the claim | String                                   |
| environment  | Yes      | Target environment for the operation          | production, Non-Production, Lab          |

## Configuration

Before using the script, configure the following variables in the appropriate environment section:
```powershell
CLIENT_ID = '<YOUR_CLIENT_ID>' CLIENT_SECRET = '<YOUR_CLIENT_SECRET>' TOKEN_URL = '<TOKEN_URL>' SCOPE = '<YOUR_SCOPE>' AUDIENCE = '<YOUR_AUDIENCE>' ACMEDNS = '<CUSTOMER.KEYFACTORPKI.COM>'
```
## Usage Examples

Show all claims:
```powershell
.\acme-claims.ps1 -action show -environment production
```
Add a new claim:
```powershell
.\acme-claims.ps1 -action add -ClaimType "sub" -ClaimValue "userguid" -Roles "EnrollmentUser" -template "acme47" -environment production
```
Update an existing claim:
```powershell
.\acme-claims.ps1 -action update -ClaimType "sub" -ClaimValue "userguid" -Roles "EnrollmentUser" -template "acme47" -environment production
```
Remove a claim (Will be presented with a list of claims to choose from):
```powershell
.\acme-claims.ps1 -action remove -environment production
```
## Error Handling

The script includes comprehensive error handling with:
- Detailed error messages
- Information logging
- Try-catch blocks for API operations

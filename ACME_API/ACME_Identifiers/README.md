# ACME Identifiers Management Script

A PowerShell script for managing ACME (Automated Certificate Management Environment) identifiers through a REST API. This tool supports multiple environments and provides functionality to add, remove, and display ACME identifiers.

## Features

- Multiple environment support (Production, Non-Production, Lab)
- OAuth authentication using client credentials
- Add new identifiers with different types (Regex, FQDN, Subnet, Wildcard)
- Remove existing identifiers
- Display all current identifiers
- Secure API communication

## Prerequisites

- PowerShell 5.1 or higher
- Valid OAuth credentials for the target environment
- Access to the ACME DNS API endpoints
- Required environment variables configured
- Keyfactor ACME 25.2.1

## Configuration

Before using the script, ensure you have the following configuration values for each environment:

- CLIENT_ID
- CLIENT_SECRET
- TOKEN_URL
- SCOPE
- AUDIENCE
- ACMEDNS endpoint

## Usage

### Basic Command Structure
```powershell
.\acme_identifiers.ps1 -environment  -Identifier  -Type  -action
```
### Parameters

- `-environment`: (Required) Target environment ["Production" | "Non-Production" | "Lab"]
- `-Identifier`: (Optional) The identifier to add or remove
- `-Type`: (Optional) Type of identifier ["Regex" | "Fqdn" | "Subnet" | "Wildcard"]
- `-action`: (Required) Action to perform ["add" | "remove" | "show"]

### Examples

Add a new FQDN identifier:
```powershell
.\acme_identifiers.ps1 -environment "Production" -Identifier "example.com" -Type "Fqdn" -action "add"
```
Show all identifiers:
```powershell
.\acme_identifiers.ps1 -environment "Lab" -action "show"
```
Remove an identifier (Will be presented a list of Identifiers to choose from):
```powershell
.\acme_identifiers.ps1 -environment "Non-Production" -action "remove"
```
## Error Handling

The script includes comprehensive error handling for:
- API communication failures
- Authentication errors
- Invalid parameter values
- General execution errors
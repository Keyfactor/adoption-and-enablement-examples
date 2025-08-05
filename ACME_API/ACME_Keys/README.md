# ACME Key Retrieval Script

A PowerShell script for retrieving ACME keys from a Keyfactor ACME API endpoint using OAuth 2.0 authentication.

## Description

This script authenticates to a Keyfactor ACME API endpoint using OAuth 2.0 client credentials flow and fetches keys based on a specified template. It provides a streamlined way to interact with the Keyfactor ACME API while handling authentication and key retrieval.

## Prerequisites

- PowerShell 5.1 or later
- Network connectivity to the Keyfactor ACME API endpoint
- Valid OAuth credentials (client ID and secret)
- Access to the Keyfactor ACME API endpoint

## Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| client_id | OAuth client ID for authentication | Yes |
| client_secret | OAuth client secret for authentication | Yes |
| Template | Name of the template for key fetching | Yes |
| token_url | OAuth token endpoint URL | Yes |
| scope | OAuth scope to request | Yes |
| audience | OAuth audience to request | Yes |
| keyfactorDnsName | DNS name of the Keyfactor ACME API endpoint | Yes |

## Usage
```powershell
.\acme_keys.ps1 `-client_id "your-client-id"` -client_secret "your-client-secret" `-Template "YourTemplate"` -token_url "(https://auth.example.com/oauth/token)" `-scope "api.read"` -audience "(https://api.example.com)" ` -keyfactorDnsName "https://keyfactor.example.com/acme"
```
## Features

- OAuth 2.0 authentication using client credentials flow
- Automated key retrieval based on template
- Formatted table output of retrieved keys
- Error handling and reporting
- Support for optional OAuth parameters (scope and audience)

## Functions

### Get-ACMEHeaders
Handles OAuth authentication and returns the required authorization headers for API calls.

### Get-keys
Retrieves keys from the Keyfactor ACME API endpoint using the specified template and authentication headers.

## Error Handling

The script includes comprehensive error handling for:
- OAuth authentication failures
- API call failures
- General execution errors

All errors are reported with detailed messages to help troubleshoot issues.

## Notes

- Ensure all required parameters are provided when running the script
- Keep your client credentials secure and never commit them to version control
- Make sure you have the necessary permissions to access the ACME API endpoint

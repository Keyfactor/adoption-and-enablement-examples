# Keyfactor Certificate Template Analyzer

## Overview

The **Keyfactor Pre 25 Check** script is a PowerShell-based tool to analyze certificate templates that do not have CSR or PFX enrollment enabled.
the goal of the script is to identify templates that do not have default setting that could create a Enrollment Pattern when upgrading to V25.

---

## Keyfactor Command Permissions
- Certitifcate Templates - Read

## Prerequisites

- **PowerShell**: Version 5.1 or later is required.
- **Network Access**: The script requires access to the Keyfactor API and identity provider (IDP) endpoints.
- **Credentials**: Ensure you have a valid OAuth2 Client ID and Secret with appropriate permissions for the API access.

---

## Features

- Authenticates using OAuth2 client credentials.
- Retrieve all certificate templates from the Keyfactor API.
- Analyzes templates for allowed enrollment types and other specific configurations.
- Outputs a detailed summary of any templates that need to have the setting set to default.

---

## Parameters

Below is a list of the parameters used in the script and their descriptions:

| Parameter        | Description                                                                                 | Mandatory | Default Value |
|------------------|---------------------------------------------------------------------------------------------|-----------|---------------|
| **KeyfactorAPI** | The base URL of the Keyfactor API. Must start with `https://`.                               | Yes       | N/A           |
| **CLIENTID**     | The OAuth2 Client ID used for authentication.                                               | Yes       | N/A           |
| **IDP_AUDIENCE** | (Optional) The audience parameter for the identity provider token request.                  | No        |       |
| **IDP_SCOPE**    | (Optional) The scope parameter for the identity provider token request.                     | No        |        |
| **TOKEN_ENDPOINT**| The OAuth2 token endpoint URL. Must start with `https://`.                                  | Yes       | N/A           |
| **loglevel**     | Log level for script output. Acceptable values: `Info`, `Debug`, `Verbose`.                 | No        | `Info`        |
| **SECRET**       | The secret associated with the Client ID.                                                   | Yes       | N/A           |

---

## Functions

### **1. Get-AuthToken**
Authenticates with the identity provider and retrieves an access token for performing operations against the Keyfactor API.

### **2. Get-Templates**
Retrieve all certificate templates from the Keyfactor API using the access token.

### **3. Get-TemplateById**
Fetches detailed information for a specific template by its ID from Keyfactor.

### **4. Invoke-CheckTemplate**
Analyze the retrieved templates for specific settings and policy configurations like **AllowedEnrollmentTypes** and outputs a summary.

---

## Usage

### Example

```powershell
.\Pre25check.ps1 -KeyfactorAPI "https://keyfactor.example.com/API" `
                 -CLIENTID "my-client-id" `
                 -TOKEN_ENDPOINT "https://idp.example.com/oauth2/token" `
                 -SECRET "my-secret" `
                 -loglevel "Verbose"
```

Here, the script:
1. Authenticates to the Keyfactor API.
2. Retrieve all available certificate templates with **AllowedEnrollmentTypes** set to 0.
3. Outputs a summary of findings for each analyzed template.

---

### Example 2

```powershell
.\Pre25check.ps1 -KeyfactorAPI "https://keyfactor.example.com/API" `
                 -CLIENTID "my-client-id" `
                 -TOKEN_ENDPOINT "https://idp.example.com/oauth2/token" `
                 -SECRET "my-secret" `
                 -IDP_SCOPE "my-scope" `
                 -IDP_AUDIENCE "my-audience" `
                 -loglevel "Verbose"
```

Here, the script:
1. Authenticates to the Keyfactor API with Audience and Scope.
2. Retrieve all available certificate templates with **AllowedEnrollmentTypes** set to 0.
3. Outputs a summary of findings for each analyzed template.

---
### Example Output

```powershell
Getting token
Token obtained successfully
Getting templates
Templates obtained successfully
Processing template: Admin_Authentication-2048-3y
Processing template: EMPTY_ENDUSER
Processing template: EMPTY_OCSPSIGNER
Processing template: EMPTY_SERVER
Templates and setting to check: {
  "Admin_Authentication-2048-3y": "TemplatePolicy.AllowWildcards",
  "EMPTY_OCSPSIGNER": "UseAllowedRequesters",
  "EMPTY_ENDUSER": "No issues found",
  "EMPTY_SERVER": "UseAllowedRequesters, TemplatePolicy.RFCEnforcement, TemplatePolicy.AllowWildcards"
}
Script execution completed
```
## Notes

- The script automatically prompts for the **SECRET** parameter securely if not provided.
- Requires appropriate permissions for the Client ID and Secret to access the Keyfactor API.
- The **AllowedEnrollmentTypes = 0** setting indicates a template configuration of interest (e.g., manual enrollment only).

---

## Output

The script generates a summary in the terminal or PowerShell window, detailing the configuration and policy findings for each template.

---

### License

This script is provided "as is" with no warranties or support.

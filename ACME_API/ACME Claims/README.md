# ACME Claims Management

A PowerShell-based utility designed to manage user claims, roles, and templates within the Keyfactor ACME service. This script provides a streamlined, menu-driven interface to perform administrative tasks across various environments.

## Features

- **Environment Switching**: Seamlessly toggle between Production, Non-Production, and Lab configurations.
- **Automated Authentication**: Handles OAuth 2.0 bearer token generation and header management automatically.
- **Claim Management (CRUD)**:
  - **View**: List all claims in a formatted table.
  - **Add**: Create new claims with specific values and roles.
  - **Update**: Modify existing claims, including adding or removing roles and templates.
  - **Remove**: Interactive deletion of claims with confirmation prompts.
- **Role Support**: Built-in support for `AccountAdmin`, `EnrollmentUser`, and `SuperAdmin` roles.

## Prerequisites

- **PowerShell**: Version 5.0 or higher.
- **Network**: Connectivity to your ACME service endpoints.
- **Permissions**: Valid OAuth 2.0 credentials for the ACME API.

## Setup & Configuration

Open `acme-claims.ps1` and locate the `Get-AcmeEnvironment` function. Replace the placeholder values with your organization's specific details for each environment:

```powershell
'Production' = @{ 
    CLIENT_ID = 'your_prod_client_id' 
    CLIENT_SECRET = 'your_prod_client_secret' 
    TOKEN_URL = '[https://your_prod_token_endpoint](https://your_prod_token_endpoint)' 
    SCOPE = 'your_prod_scope' 
    AUDIENCE = 'your_prod_audience' 
    ACMEDNS = '[https://Customer.kfdelivery.com/ACME](https://Customer.kfdelivery.com/ACME)' 
}
```

## How to Use

1. **Launch**: Execute the script in a PowerShell terminal:

   ```powershell
   .\acme-claims.ps1
   ```

2. **Select Environment**: Choose from Production, Non-Production, or Lab.
3. **Navigate Menus**:
   - Use the **Action Menu** to select between showing, adding, updating, or removing claims.
   - Follow interactive prompts for role selection and ID entry.

## Functionality Reference

| Area | Functions |
| :--- | :--- |
| **Core** | `Invoke-AcmeRequest`, `Get-AcmeHeaders`, `Test-AcmeConnection` |
| **Data** | `Get-AcmeClaims`, `Add-AcmeClaim`, `Update-AcmeClaim`, `Remove-AcmeClaim` |
| **Interface** | `Invoke-MainMenu`, `Invoke-ActionMenu`, `Show-Claims`, `Add-AcmeClaimMenu` |

---
**Author**: Keyfactor TAM Team  
**Version**: 1.0

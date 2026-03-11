# Entra Auto Provision for Keyfactor

Automatically provisions Keyfactor Security Roles and OAuth claims by syncing group membership from Microsoft Entra ID (Azure AD).

---

## Overview

This script queries a specified Entra ID (Azure AD) group for all transitive (nested) group members and ensures that each group has a corresponding **Security Role** in Keyfactor with the correct **OAuth claim** attached. It is designed to run as a scheduled task or as part of an Azure Automation Runbook.

### Support

This script is provided as-is and is not supported by Keyfactor.  It is intended to be a working example only.

### What it does

1. Authenticates to the **Microsoft Graph API** to retrieve transitive group members from a target Entra group.
2. For each member group found:
   - If no Keyfactor role exists → **creates a new role** with the appropriate OAuth claim.
   - If a role exists but is missing the OAuth claim → **updates the role** with the claim.
   - If the role already has the correct claim → **skips** (nothing to do).

---

## Prerequisites

- Python **3.10+**
- A registered **Azure App Registration** (for Microsoft Graph API access)
- A registered **OAuth Client Application** (e.g., Entra) for Keyfactor API authentication
- A running **Keyfactor Command** instance with API access
- The following Python packages (install via `pip`):
  - bash pip install requests urllib3

---

## Configuration

All configuration is managed in the `load_variables()` function. Update the values before running:

|Variable|Description|
|---|---|
|`entra_client_id`|App Registration Client ID for Microsoft Graph API|
|`entra_client_secret`|App Registration Client Secret for Microsoft Graph API|
|`entra_token_url`|Token endpoint for your Entra tenant|
|`client_id`|OAuth Client ID for Keyfactor API authentication|
|`client_secret`|OAuth Client Secret for Keyfactor API authentication|
|`token_url`|Token endpoint for your OAuth provider (e.g., Keyfactor API Client)|
|`scope`|OAuth scope required by your Keyfactor API application|
|`audience`|OAuth audience value (if required by your provider)|
|`keyfactordns`|Base URL for your Keyfactor Command API|
|`scheme`|Provider authentication scheme name as defined in Keyfactor (e.g., `azure`)|
|`all_users_group`|Display name of the Entra group whose transitive members will be processed|
|`cert_check`|Set to `False` to disable SSL verification (not recommended for production)|

> **⚠️ Important:** Do not commit credentials to source control. Use environment variables, Azure Key Vault, or Azure Automation Assets instead.

### Using Azure Automation Assets

The script includes a commented import for Azure Automation:

### import automationassets # Uncomment to use Azure Automation Assets

Uncomment this and replace the hardcoded values in `load_variables()` with calls to `automationassets.get_automation_variable()` when running in Azure Automation.

---

## Usage

Run the script directly:

- bash python kf_autoprovision.py

### Logging

Log level is set via the `log_level` variable at the top of the script:
python log_level = logging.DEBUG # Change to logging.INFO for production

Logs are written to **stdout** in the following format:
2025-01-01 12:00:00,000 - INFO - LAB - Starting Script for environment: LAB

---

## How It Works

```text
Microsoft Graph API
        │
        │  (Transitive group members of `all_users_group`)
        ▼
   EntraClient
        │
        │  List of group display names (lowercase)
        ▼
  For each group member:
        │
        ├── Role NOT found
        │       └──► Create new Role + OAuth Claim
        │
        ├── Role found, Claim MISSING
        │       └──► Update Role, add OAuth Claim
        │
        └── Role found, Claim EXISTS
                └──► Skip (no action needed)
```

> All Role create/update operations are performed via the **Keyfactor API**.

---

## Required Permissions

### Microsoft Graph API (App Registration)

| Permission | Type | Purpose |
| --- | --- | --- |
| `GroupMember.Read.All` | Application | Read transitive group members |
| `Group.Read.All` | Application | Look up group by display name |

### Keyfactor API (OAuth Client)

The OAuth client must have sufficient permissions to:

- Read and create Security Roles
- Read Permission Sets
- Create and update Claims

---

## Notes

- Group names containing `&` are automatically URL-encoded for API compatibility.
- The script processes **transitive** (nested) members, so deeply nested groups are included.
- The `Immutable` field is stripped from roles before updating, as the Keyfactor API does not accept it on PUT requests.
- The `global` Permission Set is used when creating new roles. Ensure this exists in your Keyfactor environment.

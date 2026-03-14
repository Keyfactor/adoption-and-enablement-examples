# Azure Automation Keyfactor Role and Claim Provisioning

## Overview

`provisioning.py` is an Azure Automation Python script designed to automate the creation and maintenance of **Keyfactor roles and claims** based on **Microsoft Entra ID group membership**.

The script is intended for enterprise IT operations teams responsible for identity-driven access management, certificate platform administration, and automation governance. It supports a scalable role provisioning model by using a designated **parent Entra group** as the authoritative source for downstream Keyfactor access configuration.

Under this model, the parent group contains all Entra groups that should be granted access to Keyfactor. The script retrieves the **transitive group membership** of that parent group and ensures that each qualifying group has a corresponding role and claim in Keyfactor.

This approach supports:

- Centralized access governance
- Automated provisioning
- Reduced manual administration
- Consistent role creation
- A least-privilege access model

## Purpose

The purpose of this script is to synchronize Entra group-based access assignments with Keyfactor role configuration.

For each Entra group discovered beneath the configured parent group, the script evaluates whether the corresponding Keyfactor role already exists. If it does not exist, the script creates it. If the role exists but is missing the required claim, the script updates the role accordingly.

This enables IT teams to manage access through Entra group membership while using automation to maintain alignment in Keyfactor.

## Intended Audience

This document is intended for:

- Identity and access management administrators
- PKI and Keyfactor administrators
- Azure Automation administrators
- Infrastructure and operations engineers
- IT support and platform operations personnel

## Tested Versions
- Keyfactor 26.2

## Functional Summary

The script performs the following high-level actions:

1. Loads configuration values from Azure Automation variables
2. Retrieves secrets from either:
   - Azure Automation variables, or
   - Azure Key Vault
3. Authenticates to Microsoft Graph
4. Retrieves the transitive members of a configured Entra parent group
5. Authenticates to the Keyfactor API
6. Checks whether a matching Keyfactor role exists for each group
7. Creates missing roles
8. Adds or rebuilds claims on existing roles when required
9. Logs all major actions and continues processing where possible if individual failures occur

## Architectural Model

The script assumes the use of a **master parent Entra group** that contains all Entra groups requiring access to Keyfactor, either directly or through nested group membership.

This model provides a controlled and scalable mechanism for access administration:

- IT administrators manage membership in Entra
- Azure Automation executes the synchronization workflow
- Keyfactor roles and claims are automatically aligned to the group structure

Because the script uses **transitive membership**, nested groups are supported and can be incorporated into the provisioning process without requiring manual expansion.

In Keyfactor the Role Based Access Control (RBAC) model is used to define access to Keyfactor resources.
Permissions that are granted to all users should be placed in a "Default" role. which allows for specific permissions to be defined in the group roles.

### Example
Default Role:
- Login Permissions
- Enrollment CSR
- Enrollment PFX
- My Certificates Collections

Team\Group Role:
- certificate store read for a specific application
- certificate store schedules for a specific application

This model allows for default permissions to be granted to all users and specific permissions to be granted to specific groups.


## Prerequisites

Before deploying or running this script, ensure the following prerequisites are met.

### Platform Requirements

- Azure Automation account
  - if using Azure Key Vault for secret storage, choose Managed Identity for the automation account.
- Access to Microsoft Entra ID
  - create a client credential application in Azure AD and assign the appropriate permissions to the automation account.
- Access to the Keyfactor platform and API
  - add the Entra application to Keyfactor and assign the appropriate permissions.
- Azure Key Vault access if vault-based secret storage is used
  - this would be the managed identity of the automation account.
  - the necessary role would be the "Azure Key Vault Secrets User"

### Access and Permissions

The automation identity or service principal must have appropriate permissions to:
Azure Gragh API permissions:
- Group.Read.ALL
- GroupMember.Read.All

Keyfactor API permissions:
- /security/read/
- /security/modify/

### Network Requirements

The execution environment must be able to reach:
- Microsoft Graph endpoints
- Keyfactor API endpoints
- Azure Key Vault endpoints, if applicable

## Configuration

1. Create a new Azure Automation account
2. Create a client credential application in Azure AD and assign the appropriate permissions for the Gragh API and Keyfactor API.
3. If using Azure Key Vault for secret storage, choose Managed Identity for the automation account and assign the appropriate role.
4. Create an Azure Automation Account Runbook using Python 3.10.
5. upload the required modules to the runbook. (Listed below)
6. Copy and add the script from this GitHub with no modifications and add it to the runbook.
7. Configure the runbook with the appropriate values for the automation variables. (Listed below)
8. Create a schedule for the runbook to run on a regular basis. (Do not enable till the process is tested).
9. Test the runbook to ensure it is working as expected and get an idea of how long it would take to complete.
10. Once the runbook is tested and working as expected, enable the schedule to run on a regular basis.
11. Monitor the runbook logs to ensure no errors are encountered.

### Required Automation Variables
- **environment**
  - used in logging to separate logs for different environments.
- **log_level_name**
  - used to set the logging level for the script.
  - EXAMPLE: "INFO", "DEBUG"
- **client_id**
  - The client id of the client credential application created in Azure AD.
  - Used to authenticate to the Microsoft Graph API and Keyfactor API.
- **token_url**
  - URL of the Azure AD token endpoint.
  - Used to authenticate to the Microsoft Graph API and Keyfactor API.
- **scope**
  - The scope that is defined with the Entra application in Azure AD.
  - Used to authenticate to the Microsoft Graph API and Keyfactor API.
- **audience**
  - The audience that is defined with the Entra application in Azure AD.
  - Used to authenticate to the Microsoft Graph API and Keyfactor API.
- **keyfactor_base_url**
  - the Keyfactor API URL.
  - EXAMPLE: "https://customer.keyfactorpki.com/keyfactorapi"
- **idp_scheme**
  - the name of the authentication scheme as defined in Keyfactor.  this is case-sensitive.
  - this can be obtained from the Keyfactor UI. under the settings wheel, click on the Identity Provider.
- **parent_group**
  - Name of the parent group in Entra where the nested groups are stored.
- **secret_location**
  - Used to tell the script to pull the client secret from a keyvault or automation variable.
  - Must be vault or automation
#### **If using Azure Key Vault for secret storage**
- **vault_uri**
  - the URI of the Azure Key Vault where the client secret is stored.
  - EXAMPLE: "https://myvault.vault.azure.net/"
  - Not needed if using Azure Automation variables for secret storage.
- **client-secret**
  - Optional. The client secret of the client credential application created in Azure AD.
  - Used to authenticate to the Microsoft Graph API and Keyfactor API.
#### **If using Azure Automation encrypted variable for secret storage**
- **client-secret**
  - Optional. The client secret of the client credential application created in Azure AD.
  - Used to authenticate to the Microsoft Graph API and Keyfactor API.
  - Not needed if using Azure Key Vault for secret storage.
### Required Modules
| Runtime | Module | Version |
|---|---|---|
| 3.10 | azure_core | 1.38.2 |
| 3.10 | azure_identity | 1.25.2 |
| 3.10 | azure_keyvault_secrets | 4.10.0 |
| 3.10 | certifi | 2026.2.25 |
| 3.10 | cffi | 2.0.0 |
| 3.10 | charset_normalizer | 3.4.4 |
| 3.10 | cryptography | 46.0.5 |
| 3.10 | idna | 3.11 |
| 3.10 | isodate | 0.7.2 |
| 3.10 | msal | 1.35.1 |
| 3.10 | pycparser | 3.0 |
| 3.10 | requests | 2.32.5 |
| 3.10 | typing_extensions | 4.15.0 |
| 3.10 | urllib3 | 2.6.3 |

#### From a pip install command.
```aiignore
pip download -d ./packages \
  azure-core==1.38.2 \
  azure-identity==1.25.2 \
  azure-keyvault-secrets==4.10.0 \
  certifi==2026.2.25 \
  cffi==2.0.0 \
  charset-normalizer==3.4.4 \
  cryptography==46.0.5 \
  idna==3.11 \
  isodate==0.7.2 \
  msal==1.35.1 \
  pycparser==3.0 \
  requests==2.32.5 \
  typing-extensions==4.15.0 \
  urllib3==2.6.3
```
## Logging
The script logs all major actions and continues processing where possible if individual failures occur.
The logs are written to the Azure Automation Runbook Log Stream.
Logs can be sent to a log analytics workspace for further analysis by following standard Microsoft procedures.
## Support
This process and script serves as a working example and should be used in production at your own risk.
Keyfactor does not provide support for this script and will not be responsible for any issues that may arise from its use.
Customers are responsible for implementing appropriate security measures to protect their Keyfactor environment.
# Automatic Keyfactor Provisioning

This project provides a Python-based implementation for managing Role-Based Access Control (RBAC) to Keyfactor Command using Entra Nested Groups.  The goal of this script is to run on s schedule that will pull nested groups from Entra Graph APIs and Automatically add them to Keyfactor Claims and Roles.

---

## Use Case

Create roles and claims for each group that is nested in an Entra Security group with default permissions.  Each nested group in the parent group will receive a role with predefined permissions and named with the same name of the group.  Each group in the nested group will be added as an OAuthRole claim with the name of the group being the value of the claim.  The new claim will be added to the new role to complete the process.

---

## Requirements

- **Graph API Permissions**
  - GroupMember.Read.ALL
  - Group.Read.All
- **Keyfactor**
  - V25+ (tested on V25)
  - PKIaaS, CLaaS, On-Premises
  - Configured Entra IDP
  - Client_Credential application to get bearer token added to Keyfactor Command with the following permissions:
    - /security/read/
    - security/modify/
- **Python**
  - V3.10
  - packages
    - logging
    - math
    - requests
    - json
    - urllib3
    - datetime
    - os
    - glob
- **Networking**
  - 443\https access to IDP token endpoint
  - 443\https access to keyfactor API endpoint
- **ENTRA**
  - A group of nested groups for all teams that need access to Keyfactor Command.

---

## Usage

### What the script does

#### 1. Retrieve Nested Groups from Entra

#### 2. Retrieve all Roles and OAuthRole claims from Keyfactor Command

#### 3. Script Flow

- For each group in the parent group:
  - Is the name of the group in the list of Claims pulled from Keyfactor Command?
    - no, a claim is created with the name of the group
    - yes, continues on with the script
  - Is the name of the group in the list of roles?
    - no, the role is created with default permission and the oauth claim added to it.
    - yes, is the oauth claim already in the role?
      - no, adds the claim to the role
      - yes, moves on to the next group member

### Testing

A test feature is already included in the script called Dry_run.  By changing the value dry_run = True, the script is output the log when it needs to make changes but not make the API call.

### Logging

This script will write logs to the console as well as a logfile that will be created in the same directory as the script called provisioning_log 'date'.log.
Each day will have its own log.  The script will also remove any logs older than 30 days.  This is configurable by updating the log_retention_days = 30 setting.

### Error Handling

errors are captured using a try catch functionality and written out to the consol and log file

### Configuration

Fill in the following fields at the top of the script and in the load variables definition to configure the script.

- `Proxy`:  if using a proxy uncommenting and fill in the information
- `dry_run`:  using for testing will run the script but take no actions
- `environment`:  use test or production to load variable from that environment
- `log_retention_days`:  day to retain logs
- Variables
  - `entra_client_id`: client id from the application with the graph permissions
  - `entra_client_secret`: Secret from the application with the graph permissions
  - `entra_token_url`: token endpoint from the application with the graph permissions
  - `client_id`: Client ID from the application with the keyfactor permissions
  - `client_secret`:  Secret from the application with the keyfactor permissions
  - `token_url`:  Token Url Endpoint from the application with the keyfactor permissions
  - `scope`:  Scope from the application with the keyfactor permissions
  - `audience`:  Audience from the application with the keyfactor permissions
  - `keyfactordns`:  DNS for the Keyfactor Instance (example: ' <https://customer.keyfactorpki.com/KeyfactorAPI> ')
  - `scheme`:  IDP Scheme as listed in the Keyfactor Identity Provider Page
  - `entra_all_users_group`:  Entra parent group name
  - `MODULE_LOGGER_NAME`:  name of for the logging using all something with the environment in it

---

## Support

Script is created by Keyfactor TAM group for example purposes only and is not supported by Keyfactor Support.

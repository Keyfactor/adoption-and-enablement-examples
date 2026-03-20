# ACME Administration Tool User Guide

## Overview
This tool is a command-line application for managing Keyfactor ACME-related administrative tasks such as:

- Claims
- Identifiers
- EAB keys
- Account-to-template mappings
- retrieving OAuth Subject
- System settings

The available options depend on your assigned role.

## Prerequisites
Before using the tool, make sure you have:

- A valid configuration file
- Network access to the ACME service
- Required credentials for authentication
- Any required OIDC discovery information
- Acme administrators and Account Administrators 
need to have there claim in Keyfactor Command with /enrollment_pattern/read/ Permissions.

## Installation
Download the latest release from the [releases page](https://test.pypi.org/project/kfacme/).
from a terminal window use pip to install the tool and its dependencies:
```
python.exe -m pip install --index-url https://test.pypi.org/simple --extra-index-url https://pypi.org/simple kfacme
```
### Notes
- The tool requires Python 3.10 or later.
- if app is installed manually due to network issues, you can download the wheel file from the releases page and install it manually.
- if installed manaully, you need the following dependencies wheels:
  - requests 
  - click 
  - prettytable 
  - PyJWT
The Wheels can be downloaded using the following command:
```aiignore
python -m pip download --only-binary=:all: --python-version 3.10 --implementation cp --abi cp310 --dest wheels requests click prettytable PyJWT
```
## Configuring the tool
The tool uses a configuration file to store your Keyfactor and OAuth connection information.
Once installed, move to a location where a new directory can be created and run the following command:
```aiignore
kfacme init
```
A new diretory called kfacme will be created and a veriables.py file will be created in it.
edit the variable.py with the following information:

| Setting | Value                                        |
|---|----------------------------------------------|
| scope | OIDC SCOPE                                   |
| audience | OIDC AUDIENCE                                |
| oidc_discovery_url | OIDC DISCOVERY URL                           |
| acme_dns | KEYFACTOR ACME DNS                           |
| keyfactor_dns | KEYFACTOR API DNS                            |
| cert_check | True\False                                   |
| client_id | CLIENT CREDENTIAL ALLPLICATION CLIENT ID     |
| client_secret | CLIENT CREDENTIAL ALLPLICATION CLIENT SECRET |

### Note
- The Client ID and Client Secret are optional, if they are not in the file the application will ask for them when it starts.
- Example of Keyfactor DNS: https://keyfactor.example.com/keyfactorapi
- Example of OIDC Discovery URL: https://oidc.example.com/.well-known/openid-configuration
- Example of ACME DNS: https://acme.example.com/ACME

## Starting the Tool
Run the application from the command line.  
When it starts, you may be prompted for:

- OIDC Client ID
- OIDC Client Secret

If these are not already configured in the variables.py, enter them when prompted.

To execute the tool, run the following command:
```aiignore
kfacme
```
## Main Menu
After authentication, the tool determines your role and opens the appropriate menu.

### Available Roles
- **Administrator**
- **Account Admin**
- **Enrollment User**

## Administrator Menu
If you have administrator access, you can use these options:

1. **Claims**  
   Manage claims by viewing, adding, updating, or removing them.

2. **Identifiers**  
   View, add, or remove identifiers.

3. **Get EAB Keys**  
   Retrieve EAB key information for a selected template.

4. **Get Claim Subject**  
   Extract the subject value from an access token.

5. **Change Template Mapping**  
   View accounts and update the template mapped to an account.

6. **Delete EAB Keys**  
   Revoke or remove an account’s EAB access.

7. **Manage System Settings**  
   View or modify system settings such as wildcard enrollment and certificate revocation.

8. **Exit**  
   Close the application.

## Account Admin Menu
If you have account admin access, you can use:

1. **Claims**
2. **Get EAB Keys**
3. **Get Claim Subject**
4. **Exit**

## Enrollment User Menu
If you have enrollment user access, you can use:

1. **Get EAB Keys**
2. **Get Claim Subject**
3. **Exit**

## Claims Management
Claims can be managed through the Claims menu.

### Show Claims
Displays all existing claims in a table.

### Add Claim
To add a claim:

1. Choose a claim type
2. Select one or more roles
3. Enter the claim value
4. If required, select a template
5. Confirm the action

### Update Claim
You can update:
- Role
- Template

### Remove Claim
Select the claim by ID and confirm removal.

## Identifier Management
Identifiers can be managed through the Identifiers menu.

### Supported Identifier Types
- **FQDN**
- **Regex**
- **Subnet**
- **Wildcard**

### Add Identifier
Choose a type, enter the value, and submit it.

### Remove Identifier
Select an identifier from the displayed list and remove it by index.

## Template Mapping
Use this feature to view accounts and change which template is mapped to a specific account.

## System Settings
You can view or modify system settings such as:

- Allow Wildcard Enrollments
- Certificate Revocation Enabled

## EAB Keys
The EAB key feature lets you retrieve key information for a selected template.

You must provide:

- Client ID
- Client Secret

Then choose the template you want to query.

## Error Handling
If something goes wrong, the tool may show messages such as:

- Invalid selection
- No records found
- Authentication failure
- Network or API error

If that happens, review your input and try again.

## Tips
- Use the menu numbers exactly as shown.
- Press Enter when an option allows returning to the previous menu.
- Some actions require specific permissions or settings.
- Wildcard identifiers may only work when wildcard enrollment is enabled.

## Exit
You can exit from the menu that your role provides, or close the tool from the terminal.
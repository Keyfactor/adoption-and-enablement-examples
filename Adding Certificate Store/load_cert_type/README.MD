# Keyfactor Store Automation Script

This script automates the creation of Keyfactor store types based on the specified configuration. It uses environment variables for authentication and configuration parameters.

## Features

- Easily create multiple store types in Keyfactor in one execution.
- Configure authentication and API settings through environment variables.
- Debugging options for troubleshooting.

---

## Prerequisites

Before running the script, you need the following:

- [Keyfactor](https://www.keyfactor.com/) account with appropriate credentials.
- A PowerShell environment compatible with the script.
- KFUTIL.exe installed

---

## Setup

### 1. Configure Environment Variables

You need to set up the environment variables to enable authentication and API interaction. Use the template in the script to define the variables correctly:

**Example Configuration:**

```plaintext
KEYFACTOR_HOSTNAME = "customer.keyfactorurl.com"
KEYFACTOR_API_PATH = "/KeyfactorAPI"
client_id = "<your_client_id>"
client_secret = "<your_client_secret>"
token_url = "<your_token_url>"
scope = "<your_scope>"
audience = "<your_audience>"
SelectedStoreType = "Akamai,RFPEM" # Comma-separated list of store types
KFUTIL_EXP = 0                    # Optional (used for export operations)
KFUTIL_DEBUG = 0                  # Optional (enables debug mode)
skip_verify = $true               # Skips SSL certificate verification
```

### 2. Set Environment Variables

Set the environment variables in your PowerShell session as follows:

```powershell
$env:KEYFACTOR_AUTH_CLIENT_ID = '<your_client_id>'
$env:KEYFACTOR_AUTH_CLIENT_SECRET = '<your_client_secret>'
$env:KEYFACTOR_AUTH_TOKEN_URL = '<your_token_url>'
$env:KEYFACTOR_AUTH_SCOPES = '<your_scopes>'
$env:KEYFACTOR_AUTH_AUDIENCE = '<your_audience>'
$env:KEYFACTOR_HOSTNAME = '<your_hostname>' #no slashes or HTTPS, just the DNS
$env:KEYFACTOR_API_PATH = '/KeyfactorAPI'
$env:KFUTIL_EXP = 0
$env:KFUTIL_DEBUG = 0
$env:KEYFACTOR_SKIP_VERIFY = $true
```

You can also include these settings in a script or environment profile for easier reuse.

---

## Usage

1. **Edit the `SelectedStoreType` variable**  
   Specify the store types to create in the `SelectedStoreType` field. Use a comma-separated list if multiple store types are required.  You can get the Storetype from the Capability GitHub Page or running the kfutil_get_cap.ps1.

   Example:

   ```powershell
   $Variables.SelectedStoreType = "Akamai,RFPEM"
   ```

2. **Run the Script**  
   Execute the script in your PowerShell environment:

   ```powershell
   <script_name>.ps1
   ```

   The script will read the configuration and create the specified store types in Keyfactor.

---

## Debugging

If you encounter an issue, enable debug mode by setting the `KFUTIL_DEBUG` variable to `1`:

```powershell
$env:KFUTIL_DEBUG = 1
```

This will provide additional details to help troubleshoot the problem.

---

## Notes

- Ensure that the required permissions are granted for the specified `client_id` to create store types in Keyfactor.
- Use the `skip_verify` option cautiously if SSL verification is critical in your environment.

### Support

This script has no Keyfactor Support and is used as a working example.

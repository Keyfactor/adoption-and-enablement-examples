
---

# **User Instructions**

This script is designed for automating the installation and configuration of services (e.g., Keyfactor Orchestrator). Follow the steps below to customize and run the script.

---

# **Script Support**

This script is a working example that Keyfactor customers may use or modify as needed.  Keyfactor will not support this script.

---

## **1. Prerequisites**

Before running the script, ensure the following:
- **PowerShell Version**: Use at least PowerShell version 5.0 or higher.
- **Install Script**: Ensure the `install.ps1` file is available in the specified directory.
- **Permissions**: Run the script with administrative privileges if required for installation.
- **Required Details**: Gather the authentication details (e.g., client ID, client secret, or username/password).
- **Software Requirements**: Read the requiremtns for installing the Universal Orchestrator for installing on a Windows System.
---

## **2. Customizing the Script**

1. **Open the Script**:
   - Open the PowerShell script in any text editor or IDE (e.g., Windows PowerShell ISE or PyCharm).

2. **Modify Configuration Variables**:
   - Locate the `$script:Variables` hashtable at the beginning of the script.
   - Update the following variables as needed:
     - **API Hostname**:  
       Update `KEYFACTOR_HOSTNAME` with the URL of your Keyfactor API.  
       Example:  
```
KEYFACTOR_HOSTNAME = "https://yourdomain.com/KeyfactorAPI"
```
     - **Installation Directory**:  
       Specify the directory containing `install.ps1` in `install_directory`.  
       Example:  
```
install_directory = "C:\Keyfactor\InstallationScripts"
```
     - **Authentication Method**:  
       Set `Auth_Method` to either:
       - `"oauth"`: For OAuth authentication.
       - `"basic"`: For Basic Authentication.
     - **OAuth-Specific Parameters** (if using OAuth):
       - `client_id`, `client_secret`, `token_url`, `scope`, `audience`
     - **Basic Authentication (if using Basic)**:
       - `keyfactorUser` and `keyfactorPassword` (user credentials).

3. **Optional Changes**:
   - If you are using a service account, set `use_service_account = $true` and provide valid `serviceUser` and `servicePassword`.

---

## **3. Running the Script**

1. **Open PowerShell**:
   - Open PowerShell with administrative privileges.

2. **Navigate to the Script Directory**:
   - Navigate to the directory containing the script file using the `cd` command.  
     Example:  
```powershell
cd C:\Path\To\Script
```

3. **Execute the Script**:
   - Run the script in PowerShell:
```powershell
.\UO_Install.ps1
```
   - The script will:
     - Validate the presence of `install.ps1`.
     - Perform the installation depending on the authentication method specified (`oauth` or `basic`).

---

## **4. Troubleshooting**

- **Missing `install.ps1` File**:
  - Make sure the `install.ps1` file is placed in the directory specified in the `install_directory` variable.
  - Update the `install_directory` to the correct location if necessary.

- **Invalid Credentials**:
  - Verify that the credentials provided (`keyfactorUser`, `keyfactorPassword`, `client_id`, `client_secret`, etc.) are correct and have required permissions.

- **Error Loading Variables**:
  - Check the `$script:Variables` block for any syntax issues.
  - Ensure all required variables are properly set.

- **Admin Permission Errors**:
  - Relaunch PowerShell with administrative privileges and try again.

---

## **5. Script Behavior**

- If the installation succeeds:
  - The script finishes execution without errors.
- If the installation fails:
  - Detailed error messages will be displayed, indicating the issue (e.g., invalid credentials, missing files, etc.).
- The script will warn the user and halt if:
  - Required configuration variables are missing.
  - `install.ps1` is not found.

---

## **6. Example Configuration**

Here is an example of a filled `$script:Variables` block:

```powershell
$script:Variables = @{
    KEYFACTOR_HOSTNAME  = "https://mycompany.keyfactor.com/KeyfactorAPI"
    install_directory   = "C:\Keyfactor\InstallationScripts"
    use_service_account = $true
    Auth_Method         = "oauth"
    serviceUser         = "service_user"
    servicePassword     = "secure_password"
    keyfactorUser       = ""
    keyfactorPassword   = ""
    client_id           = "oauth_client_id"
    client_secret       = "oauth_client_secret"
    token_url           = "https://mycompany.keyfactor.com/oauth/token"
    scope               = "all"
    audience            = "https://mycompany.keyfactor.com"
}
```

---

**For more advanced use cases or issues, refer to the documentation of the application you're installing or ask for further support.**

--- 

# PowerShell Script Explanation: `keyfactor_onboarding.ps1`

The provided PowerShell script is designed for onboarding and managing **Keyfactor roles, collections, and claims** in a Keyfactor environment. Below is a breakdown of the script's purpose, its key features, and examples of how it functions.

---

## **Purpose**

The script automates several Keyfactor management tasks, including:
1. Creating **collections**: Collections group certificates and manage operations on those groups.
2. Defining **roles**: Roles assign permissions to users or systems for working with collections.
3. Managing **OAuth-based claims**: Adds claims (e.g., `OAuthRole`, `OAuthSubject`) to roles for authentication/authorization purposes.
4. Supporting **multi-environment configurations**: Works with various environments like `Production`, `NonProduction`, `Lab`, or user-defined configuration files.

---

## **Key Features**
### **1. Multi-Environment Support**
The script allows onboarding in different deployment environments:
- **Production**: Production-ready configurations.
- **NonProduction**: For testing/staging environments.
- **Lab**: Testing setups.
- **FromFile**: Dynamically loads variables from an external configuration file (in Hashtable format).

### **2. Automation of Keyfactor Operations**
The script automates:
- Creating/updating **roles** and **collections**.
- Setting **permissions** for roles (e.g., `read`, `modify`, `revoke`).
- Adding OAuth claims for roles and mapping authentication details.

### **3. Flexible Validation**
- **Switch Parameters** (like `-Force`) allow bypassing certain validations to streamline batch operations.
- Logging can be customized using one of three levels: `Info`, `Debug`, or `Verbose`.

### **4. Modularity**
The script uses reusable **functions** (like `process_roles`, `process_claims`) to enhance code modularity and simplify debugging.

---

## **Parameters**

| **Parameter**          | **Description**                                                                                                                                                                                                 |
|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `environment_variables` | **(Required)** Specifies the environment to work with. Options: `Production`, `NonProduction`, `Lab`, `FromFile`.                                                                                              |
| `role_name`             | **(Required)** The name of the role or collection to be created.                                                                                                                                               |
| `role_email`            | **(Optional)** Email to associate with the role.                                                                                                                                                              |
| `Claim`                | **(Optional)** The value of the claim to assign to the role (e.g., a group name).                                                                                                                              |
| `Claim_Type`            | **(Required if Claim is provided)** Type of claim. Options: `OAuthRole`, `OAuthSubject`.                                                                                                                      |
| `Force`                | **(Optional Switch)** Forces the script to continue even if certain validations (like missing `role_email`) fail.                                                                                              |
| `loglevel`             | **(Optional)** Log output level. Options: `Info`, `Debug`, `Verbose`. Default: `Info`.                                                                                                                         |
| `RoleOnly`              | **(Optional Switch)** Only creates roles, skipping collections and claims.                                                                                                                                    |
| `variableFile`          | **(Optional)** Path to a custom variable file in Hashtable format, which dynamically loads additional settings (useful for user-specific scenarios).                                                           |

---

## **Key Functions**

### **1. `load_variables`**
- Dynamically loads and sets **static variables** (e.g., collection descriptions, permissions) and **environment-specific variables** (e.g., API credentials).
- Switches behavior based on `environment_variables` (e.g., `Production`, `NonProduction`, `Lab`).
- Returns a combined set of static and environment-specific variables for use throughout the script.

---

### **2. `process_roles`**
- Checks if a role with the specified name (`role_name`) exists in Keyfactor.
- If it doesn't, creates the role and associates it with the appropriate collection ID (`collectionid`) and permissions.

---

### **3. `process_collections`**
- Checks if a collection exists for the specified role.
- If it doesn’t, creates a **new collection** for the role and associates the collection with the role name.
- Sets collection-level permissions based on pre-defined policies.

---

### **4. `process_claims`**
- Checks if the specified **OAuth claim** (`Claim` parameter) exists.
- If not, creates the claim and associates it with the selected role (`roleid`).

---

### **5. `Invoke-HttpGet` / `Invoke-HttpPost` / `Invoke-Http_Put`**
- Helper functions for making API requests via HTTP:
  - **GET**: Retrieve data about roles, collections, claims, etc.
  - **POST**: Create new resources (e.g., collections, claims, roles).
  - **PUT**: Update existing resources.

---

### **6. `Check_KeyfactorStatus`**
- Validates whether the Keyfactor environment is running and accessible by making an API call.
- Logs status messages about connectivity.

---

### **7. `Update-RoleClaim`**
- Adds the specified claim to a role if the claim does not already exist in the role.
- Updates the role data with the new claim.

---

## **Logging**
- Verbose logging for **debugging** uses the `-loglevel` parameter:
  - **Info**: Standard operational logs.
  - **Debug**: Detailed logs for troubleshooting.
  - **Verbose**: Step-by-step execution tracking.

---

## **Example Use Cases**

### **1. Create a Role and Collection with a Claim (Production)**
```powershell
.\keyfactor_onboarding.ps1 -environment Production -role_name AdminRole -role_email admin@example.com -Claim GroupClaim -Claim_Type OAuthRole
```
- Creates a **collection** and **role** called `AdminRole` in the `Production` environment.
- Associates the role with the claim `GroupClaim` of type `OAuthRole`.

---

### **2. Role Without Collection or Claim**
```powershell
.\keyfactor_onboarding.ps1 -environment Lab -role_name TestRole -RoleOnly
```
- Creates only the role called `TestRole` in the `Lab` environment, skipping collections and claims.

---

### **3. Override Email Validation**
```powershell
.\keyfactor_onboarding.ps1 -environment NonProduction -role_name DevRole -Force
```
- Executes without requiring an email address, as the `-Force` flag bypasses email-related validations.

---

### **4. Load Variables from an External File**
```powershell
.\keyfactor_onboarding.ps1 -environment FromFile -role_name ConfigBasedRole -Force -variableFile "C:\Config\Variables.ps1"
```
- Loads environment variables from `Variables.ps1` and creates `ConfigBasedRole`.

---

## **Key Example Breakdown**

```powershell
.\keyfactor_onboarding.ps1 -environment Production -role_name AdminRole -role_email admin@example.com -Claim GroupClaim -Claim_Type OAuthRole
```

**Execution Flow:**
1. **Environment Setup**: Loads `Production` environment variables (e.g., API credentials, URLs).
2. **Role Creation**:
   - Checks if `AdminRole` exists. If not, creates it with the provided email and associates it with default permissions.
3. **Claim Management**:
   - Checks if the claim `GroupClaim` exists. If not, creates it with the type `OAuthRole`.
   - Links the claim to the `AdminRole`.

---

## **Error Handling**
- Errors are logged using a custom `write-message` function.
- `Force` switch ensures uninterrupted execution, even if certain parameters (e.g., `role_email`) are missing.
- Keyfactor connection validation (`Check_KeyfactorStatus`) stops execution if the API is unreachable.

---

## **Conclusion**

This script is a powerful and flexible tool for automating Keyfactor onboarding processes, including creating roles, collections, and managing claims for OAuth-based integrations. It supports diverse environments, dynamic configurations, and modularity to simplify large-scale deployments.
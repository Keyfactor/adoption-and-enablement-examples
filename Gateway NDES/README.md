
# Gateway NDES Installation Guide

## Pre-requisites

- **Enterprise Administrator** as the installing account.
- **SCEP service account** (can be the same as the accounts running the gateway services).
- **Custom install script** for Microsoft certsvc (original location moved).
- **Internet access** for applications.
- **Enrollment Gateway Logical Name** must match the Cloud hosted CA certificate.

## Install Steps

1. **Permissions:**
   Grant the installing account the following on the Gateway configuration wizard:
   - Manage CA
   - Issue and Manage Certificates
   - Read
   - Request

1. **Publish Certificate Templates:** Publish the following templates on the Gateway:
   - IPSec (offline request)
   - Exchange Enrollment Agent (offline request)
   - CEP Encryption  (CSS will do the same.)

1. **Run Custom Install Script:**
   - On the Gateway, run the custom install script (`install.bat`) from a CMD prompt as administrator.  
   - Navigate to the file location on the Windows Cloud Gateway server (`Gateway_Pieces_for_NDES.zip`).  
   - Ensure `CerSvcNDESPlaceholder.exe` is in the same directory as `install.bat`.

1. **Service Account Configuration:**
   - The account running the service `CertSvcNDesPlaceholder` on the gateway should be either the local system or the local service account, depending on which one starts the service (as determined by internal security policy).
1. **Install Microsoft NDES/SCEP.**

1. **Configure SPN and Delegation:**
   - Set the SPN with the SCEP service account and configure constrained delegation on the account.
1. **Create MDM Template:**
   - The SCEP service account will need enroll permissions on the template.

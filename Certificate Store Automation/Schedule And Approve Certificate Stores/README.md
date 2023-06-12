# **Document Version Control**

| **_Date_** | **_Author_** | **_Comments_** |
|--|--|--|
| 6/12/2023 | Forrest McFaddin | Initial commit of process |

# **Supported Versions**

Keyfactor Command 10.X

# **Overview**
This automation script allows Keyfactor administrators to perform mass discovery and approval of the following certificate store types:
1. Remote File - JKS (RFJKS)
2. Remote File - PEM (RFPEM)
3. Remote File - PKCS12 (RFPKCS12)

Multiple executions of this script are required to complete the discovery and approval phases of this process. After each execution, the user will add additional information to newly created files that this script creates, which will be used in the next step.

The different phases of this script are below:

1. [Script]  Create a "Machine Details" file.
2. [User]    Populate server details in the "Machine Details" file.
2. [Script]  Create Discovery jobs to discover certificate stores on machines provided in the machine details file.
3. [Script]  Export newly discovered Certificate Stores to a "Pending Cert Stores" file.
4. [User]    Populate certificate store details in the "Pending Cert Stores" file.
5. [Script]  Approve pending Certificate Stores using details in the pending cert stores file.

# **Requirements**

* At least one configured Universal Orchestrator

* The RFJKS,RFPEM,RFPKCS12 Certificate Store types must be created prior to running the script.

# **Execution**

1.  Copy the script to a Windows server that is running PowerShell 5.
2.  Update the mandatory variables with your Keyfactor Command information.

```
# **Document Version Control**

| **_Date_** | **_Author_** | **_Comments_** |
|--|--|--|
| 10/09/2023 | Forrest McFaddin | Initial commit |

# **Keyfactor Prerequisite Validation Script**

The Keyfactor Prerequisite Validation script will validate server, application, and network prerequisites for the following Keyfactor services:

1. Keyfactor Cloud Enrollment Gateway
2. Keyfactor Universal Orchestrator

If certain prerequisites have failed to be met, the script displays some additional information that seeks to help remediate the problem.

Disclaimer: This script does not configure or remediate missing prerequisites on a server. Keyfactor is not responsible for instructing customers on how
to remediate failed prerequisites outside of reasonable suggestions for remediation.


# Execution #

1. Copy the script to the appropriate server that will have the Keyfactor Cloud Enrollment Gateway or Universal Orchestrator installed on.
2. Run the script as an administrator
3. Read and follow the prompts, entering the appropriate when prompted.
4. Once the script completes, review the results and attempt to remediate any "FAILED" items.
5. Run the script again to check again, as needed. 

> Note: Restarting PowerShell before subsequent runs might be necessary for certain prerequisites to "PASS."

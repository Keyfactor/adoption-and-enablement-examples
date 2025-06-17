# Batching Script for Keyfactor Onboarding

## Overview
The `Batching.ps1` script processes a CSV file to execute the Keyfactor onboarding PowerShell script (`keyfactor_onboarding.ps1`) in parallel using runspaces. It is designed to streamline the onboarding process by processing multiple entries concurrently.

---

## Features
- **Parallel Processing**: Utilizes runspaces to process multiple CSV entries simultaneously.
- **Logging**: Logs the output of each runspace execution to individual log files.
- **Validation**: Ensures the required script file and CSV data are valid before execution.
- **Customizable**: Supports optional parameters like `roleonly` and `variableFile` for flexible execution.

---

## Prerequisites
- **PowerShell Version**: Windows PowerShell 5.1 or later.
- **Required Files**:
  - `keyfactor_onboarding.ps1` must be present in the same directory as the script.
  - A valid CSV file with the required columns: `name`, `email`, `claim`, and `claimType`.
  - Optional: A hashtable file for additional variables.

---

## Parameters
| **Parameter**   | **Description**                                                                                     | **Mandatory** | **Default** |
|------------------|-----------------------------------------------------------------------------------------------------|---------------|-------------|
| `csvPath`        | Path to the CSV file containing the data to be processed.                                           | ✅ Yes        | N/A         |
| `maxThreads`     | Maximum number of threads to use for the runspace pool.                                             | ✅ Yes        | N/A         |
| `roleonly`       | Switch to prevent the creation of collections.                                                      | ❌ No         | `$false`    |
| `variableFile`   | Path to a hashtable file containing variables required for the onboarding process.                  | ✅ Yes        | N/A         |

---

## CSV File Requirements
The CSV file must include the following columns:
- `name`: The name of the role.
- `email`: The email address associated with the role.
- `claim`: The claim to be assigned.
- `claimType`: The type of the claim.

---

## Usage
### Example 1: Basic Execution
```powershell
Batching.ps1 -csvPath "C:\data\users.csv" -maxThreads 25 -variableFile "C:\config\variables.ps1"
```
Processes the users.csv file with a maximum of 5 threads and uses the variables defined in variables.ps1.

### Example 2: Role-Only Execution
```powershell
Batching.ps1 -csvPath "C:\data\users.csv" -maxThreads 25 -roleonly -variableFile "C:\config\variables.ps1"
```
Processes the users.csv file without creating collections.

## Logging
- Logs are stored in the `RunspaceLogs` directory within the script's directory.
- Each log file is named using the format: `<name>_<timestamp>.log`.


## Error Handling
- `Malformed CSV Data`: Skips rows with missing or invalid data and logs a warning.
- `Missing Script File`: Stops execution if keyfactor_onboarding.ps1 is not found.
- `General Errors`: Displays error messages and stack traces in the console.


## Multi-threading Test Results
| **Test** |**Description** | **# of Entries** |**Time (Min)** 
|-----------|----------------|------------------|---------------
|`Single Add` | No Multithreading and adding Collection, Role, and Claim | 1 | 9 Sec 
|`No Collection` | Multithreading 50 at a time and adding Role, and Claim with no Collection | 1000 | 16 Min
|`Everything` | Multithreading 50 at a time and adding Collection, Role, and Claim | 1000 | 13 Min

## Notes
- Ensure that the `keyfactor_onboarding.ps1` script is present in the same directory as `Batching.ps1`.
- For each thread, a new log file is created that is the output of the runspace it was ran in.
- Each log takes up about 2 kb, if you run 1000 enties you will get 1000 logs in the RunspaceLogs directory that is created.
- The script measures and displays the total elapsed time for processing all CSV lines.

## License
This script is licensed under the MIT License.

## Links
- [Explination of Batch Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/OnBoarding/BatchCode.md)
- [Explination of Onboarding Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/OnBoarding/Code.md)
- [Batching Script](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/OnBoarding/Batching.ps1)
- [OnBoarding Script](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/OnBoarding/keyfactor_onboarding.ps1)
- [Variable File](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/Team-Onboarding/OnBoarding/Variables.ps1)
- [Keyfactor Command Documentation](https://software.keyfactor.com)
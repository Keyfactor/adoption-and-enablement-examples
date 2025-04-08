<#
.SYNOPSIS
This script processes a CSV file and executes a PowerShell script (`keyfactor_onboarding.ps1`) in parallel using runspaces.

.DESCRIPTION
The script reads data from a CSV file and uses a runspace pool to execute the `keyfactor_onboarding.ps1` script for each row in the CSV. 
The number of concurrent threads is controlled by the `$script:maxThreads` variable. Each runspace is assigned a set of parameters 
from the CSV file and executed in parallel.

.PARAMETER CSV_PATH
The file path to the CSV file containing the data to be processed. Each row in the CSV should include the columns `name`, `email`, 
`claim`, and `claimType`.

.PARAMETER maxThreads
The maximum number of threads to use for the runspace pool. This controls the level of concurrency.

.NOTES
- The script assumes that the `keyfactor_onboarding.ps1` script is located in the same directory as this script.
- The `keyfactor_onboarding.ps1` script is executed with the following parameters:
    - `-environment_variables` set to `Production`
    - `-role_name`, `-role_email`, `-Claim`, and `-Claim_Type` populated from the CSV file.
- -environment_variables is a placeholder and should be replaced with the actual environment variable if needed.
- The script uses the `Import-Csv` cmdlet to read the CSV file and the `AddScript` method to add the script block to each runspace.

.EXAMPLE
# Example usage:
$script:CSV_PATH = 'C:\path\to\data.csv'
$script:maxThreads = 5
.\Batching.ps1

# This will process the `data.csv` file using a maximum of 5 concurrent threads.

#>

$script:CSV_PATH     = '' # Path to the CSV file containing the data
$script:maxThreads = '' # Maximum number of threads to use for runspaces

# Import the CSV file
$csvData = Import-Csv -Path $CSV_PATH

# Create a runspace pool with maximum threading
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
$runspacePool.Open()

# Create a collection to hold the runspaces
$runspaces = @()

foreach ($line in $csvData) {
    # Create a new runspace
    $runspace = [powershell]::Create().AddScript({
        param ($name, $email, $claim, $claimType)
        .\keyfactor_onboarding.ps1 -environment_variables Production -role_name $name -role_email $email -Claim $claim -Claim_Type $claimType
    }).AddArgument($line.name).AddArgument($line.email).AddArgument($line.claim).AddArgument($line.claimType)

    # Assign the runspace pool to the runspace
    $runspace.RunspacePool = $runspacePool

    # Start the runspace and add it to the collection
    $runspaces += [PSCustomObject]@{
        Pipe = $runspace
        Status = $runspace.BeginInvoke()
    }
}

# Wait for all runspaces to complete
foreach ($runspace in $runspaces) {
    $runspace.Pipe.EndInvoke($runspace.Status)
    $runspace.Pipe.Dispose()
}

# Close the runspace pool
$runspacePool.Close()
$runspacePool.Dispose()
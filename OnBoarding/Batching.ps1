<#
.SYNOPSIS
Processes a CSV file to execute a PowerShell script in parallel using runspaces.

.DESCRIPTION
This script reads a CSV file containing user data and processes each line in parallel using runspaces. 
It validates the input, creates necessary directories, and logs the output of each runspace execution. 
The script is designed to onboard users by invoking a specified PowerShell script with parameters derived from the CSV data.

.PARAMETER csvPath
The path to the CSV file containing the data to be processed. The CSV must include the following columns: 
'name', 'email', 'claim', and 'claimType'.

.PARAMETER maxThreads
The maximum number of threads to use for the runspace pool.

.PARAMETER roleonly
A switch parameter that, when specified, prevents the creation of collections. Default is $false.

.PARAMETER variableFile
The path to a hashtable file containing variables required for the onboarding process.

.FUNCTION CreateLogDirectory
Creates a directory for storing log files if it does not already exist.

.FUNCTION ValidateScriptFile
Validates the existence of the required script file ('keyfactor_onboarding.ps1') in the specified script path.

.FUNCTION ProcessCsvLine
Processes a single line from the CSV file by creating a runspace to execute the onboarding script with the provided parameters.

.EXAMPLE
.\Batching.ps1 -csvPath "C:\data\users.csv" -maxThreads 5 -variableFile "C:\config\variables.ps1"

This example processes the 'users.csv' file with a maximum of 5 threads and uses the variables defined in 'variables.ps1'.

.NOTES
- The script logs the output of each runspace execution to a file in the 'RunspaceLogs' directory.
- The script measures and displays the total elapsed time for processing all CSV lines.
- Ensure that the 'keyfactor_onboarding.ps1' script exists in the current working directory.

#>

param (
    [Parameter(Mandatory, Position = 0, HelpMessage = "Path to the CSV file containing the data")]
    [string]$csvPath,
    [Parameter(Mandatory, Position = 1, HelpMessage = "Maximum number of threads to use for runspaces.")]
    [int]$maxThreads,
    [Parameter(Position = 2, HelpMessage = "Will not create collections. Default is false.")]
    [Switch]$roleonly = $false,
    [Parameter(Mandatory, Position = 3, HelpMessage = "Hashtable files containing needed variables.")]
    $variableFile
)

function CreateLogDirectory($logPath) {
    if (-not (Test-Path -Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory | Out-Null
        Write-Host "Log directory created at: $logPath" -ForegroundColor Green
    }
}

function ValidateScriptFile($scriptPath) {
    if (-not (Test-Path -Path (Join-Path $scriptPath "keyfactor_onboarding.ps1"))) {
        Write-Host "Script file does not exist in $scriptPath." -ForegroundColor Red
        exit 1
    }
}

function ProcessCsvLine($line, $scriptPath, $variableFile, $runspacePool, $runspaces) {
    if (-not ($line.PSObject.Properties.Match('name') -and
              $line.PSObject.Properties.Match('email') -and
              $line.PSObject.Properties.Match('claim') -and
              $line.PSObject.Properties.Match('claimType'))) {
        Write-Host "Skipping malformed or missing data in CSV: $($line | Out-String)" -ForegroundColor Yellow
        return
    }

    Write-Host "Processing: $($line.name) with email: $($line.email) and claim: $($line.claim) of type: $($line.claimType)"

    $runspace = [powershell]::Create().AddScript({
        param (
            $name,
            $email,
            $claim,
            $claimType,
            $scriptPath,
            $variableFile,
            $roleonly = $false
        )

        $tokenParams = @{
            environment_variables   = "FromFile"
            role_name               = $name
            role_email              = $email
            Claim                   = $claim
            Claim_Type              = $claimType
            loglevel                = "Debug"
            variableFile            = $variableFile
        }

        if ($roleonly){$tokenParams["roleonly"] = $true}

        $output = & {
            Set-Location $scriptPath
            . .\keyfactor_onboarding.ps1 @tokenParams
        } *>&1 | Out-String
        
        $timestamp = (Get-Date -Format "yyyyMMddHHmmssfff")
        $logFilePath = "$($scriptPath)\RunspaceLogs\$($name)_$($timestamp).log"
        $output | out-file -FilePath $logFilePath -Append -Encoding UTF8
        
        # $output | Out-File -FilePath "$($scriptPath)\RunspaceLogs\$($name)_runspace_$timestamp.log" -Append
    }).AddArgument($line.name).AddArgument($line.email).AddArgument($line.claim).AddArgument($line.claimType).AddArgument($scriptPath).AddArgument($variableFile).AddArgument($roleonly)

    $runspace.RunspacePool = $runspacePool
    $runspaces.Add([PSCustomObject]@{
        Pipe = $runspace
        Status = $runspace.BeginInvoke()
    }) | Out-Null
}

try {
    # Create a new Stopwatch object
    $stopwatch = New-Object System.Diagnostics.Stopwatch

    # Start the stopwatch
    $stopwatch.Start()

    # Import the CSV file
    $csvData = Import-Csv -Path $csvPath

    # Set the script path and log path
    $scriptPath = (Get-Location).Path
    $logPath = Join-Path -Path $scriptPath -ChildPath "RunspaceLogs"

    # Create the log directory and validate the script file
    CreateLogDirectory -logPath $logPath
    ValidateScriptFile -scriptPath $scriptPath

    # Initialize runspace pool and process CSV lines
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
    $runspacePool.Open()
    $runspaces = [System.Collections.ArrayList]@()

    foreach ($line in $csvData) {
        ProcessCsvLine -line $line -scriptPath $scriptPath -variableFile $variableFile -runspacePool $runspacePool -runspaces $runspaces
    }

    # Finalize runspaces
    foreach ($runspace in $runspaces) {
        $runspace.Pipe.EndInvoke($runspace.Status)
        $runspace.Pipe.Dispose()
    }

    $runspacePool.Close()
    $runspacePool.Dispose()
    # Stop the stopwatch
    $stopwatch.Stop()

    # Get the elapsed time
    $elapsedTime = $stopwatch.Elapsed

    # Display the elapsed time
    Write-Host "$elapsedTime"

    # Reset the stopwatch
    $stopwatch.Reset()

} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Yellow
}
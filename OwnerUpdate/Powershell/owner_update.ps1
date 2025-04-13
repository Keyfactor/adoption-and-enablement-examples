<#
.SYNOPSIS
    Updates certificate owners in Keyfactor Command using multithreading.

.DESCRIPTION
    This script processes a CSV file containing certificate serial numbers and roles, 
    and updates the certificate owners in Keyfactor Command. It uses multithreading 
    with runspaces to improve performance and logs the results for each operation.

.PARAMETER csvPath
    Path to the CSV file containing the data. The CSV file should include columns 
    for certificate serial numbers and roles.

.PARAMETER maxThreads
    Maximum number of threads to use for runspaces. Determines the level of 
    concurrency for processing the CSV data.

.PARAMETER variableFile
    Path to a file containing a hashtable of variables required for the script, 
    such as API credentials and URLs.

.EXAMPLE
    .\owner_update.ps1 -csvPath "C:\data\certificates.csv" -maxThreads 5 -variableFile "C:\config\variables.ps1"
    Processes the certificates in the specified CSV file using 5 threads and 
    loads variables from the specified file.

.NOTES
    - The script validates the connection to Keyfactor Command before processing.
    - Logs are created in a "RunspaceLogs" directory in the script's location.
    - Requires PowerShell 5.1 or later.

.FUNCTIONS
    - CreateLogDirectory: Creates a directory for logs if it doesn't exist.
    - new-logentry: Writes log entries to a file for each certificate processed.
    - create_auth: Generates authentication headers using client credentials.
    - Invoke-HttpPut: Sends HTTP PUT requests with authentication headers.
    - Invoke-HttpGet: Sends HTTP GET requests with authentication headers.
    - Check_KeyfactorStatus: Validates the connection to Keyfactor Command.
    - Get-Certificates: Retrieves the certificate ID for a given serial number.
    - Get-RoleId: Retrieves the role ID for a given role name.
    - Update-CertificateOwner: Updates the owner of a certificate.

.OUTPUTS
    - Logs are written to individual files for each certificate processed.
    - Elapsed time for the operation is displayed in the console.

#>
param (
    [Parameter(Mandatory, Position = 0, HelpMessage = "Path to the CSV file containing the data")]
    [string]$csvPath,
    [Parameter(Mandatory, Position = 1, HelpMessage = "Maximum number of threads to use for runspaces.")]
    [int]$maxThreads,
    [Parameter(Mandatory, Position = 2, HelpMessage = "Hashtable files containing needed variables.")]
    $variableFile
)

try
{
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

    #load variabe file
    if ($variableFile)
    {
        . .\$variableFile

        write-host "Loaded variables from $variableFile"
    }
    else
    {
        Throw "No variable file provided."
    }

    if (!$Variables.CLIENT_SECRET)
    {
        $CLIENT_SECRET = Read-Host "Please enter your IDP Applications Client Secret"

        $Variables.CLIENT_SECRET = $CLIENT_SECRET

        Write-Host "Saved Client_Secret in Memory Only" -ForegroundColor Green
    }

    # Validate the variables
    if ($Variables.CLIENT_ID)
    {
        write-host  "Validating access to Variables"
    }
    else
    {
        throw  "Failed to validate Variables"
    }


    # Multithreading setup with Runspaces
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
    $runspacePool.Open()

    # Collection of threads (Runspaces)
    $runspaces = @()

    foreach ($line in $csvData) 
    {
        $runspace = [powershell]::Create().AddScript({

            param (
                $line, 
                $variables, 
                $logPath
            )

            function new-logentry
            {
                param (
                    [Parameter(Mandatory = $true)]
                    [string]$message
                )

                $logFile = Join-Path -Path $logPath -ChildPath "log_$($line.serial).log"

                $currentDate = (Get-Date -UFormat "%d-%m-%Y")

                $currentTime = (Get-Date -UFormat "%T")

                $Message = "[$currentDate $currentTime] $Message"

                $Message | out-file -FilePath $logFile -Append -Encoding utf8
            }
            function create_auth
            {
                param (
                    [Parameter(Mandatory = $true)]
                    $HeaderVersion,
                    [Parameter(Mandatory = $true)]
                    [hashtable]$Variables
                )
                $headers = @{
                    'Content-Type' = 'application/x-www-form-urlencoded'
                }
                $body = @{
                    'grant_type' = 'client_credentials'
                    'client_id' = $($Variables.client_id)
                    'client_secret' = $($Variables.client_secret)
                }
                if ($Variables.scope){$body['scope'] = $Variables.scope}
                if ($Variables.audience){$body['audience'] = $Variables.audience}

                try
                {
                    $access_token = (Invoke-RestMethod -Method Post -Uri $Variables.TOKEN_URL -Headers $headers -Body $body).access_token

                    new-logentry -Message "Successfully received Access Token from $($Variables.TOKEN_URL)"
                }
                catch
                {
                    throw "Error in create_auth: $($_.Exception.Message)"
                }
                return @{
                    "content-type"                  = "application/json"
                    "accept"                        = "text/plain"
                    "x-keyfactor-requested-with"    = "APIClient"
                    "x-keyfactor-api-version"       = "$HeaderVersion.0"
                    "Authorization"                 = "Bearer $access_token"
                }
            }

            function Invoke-HttpPut
            {
                [CmdletBinding()]
                param
                (
                    [Parameter(Mandatory = $true)]
                    [string]$url,
                    [Parameter(Mandatory = $true)]
                    [string]$HeaderVersion,
                    [Parameter(Mandatory = $true)]
                    [hashtable]$Variables,
                    [Parameter(Mandatory = $true)]
                    $Data
                )
                Try
                {
                    new-logentry -Message "Sending HTTP Put request to URL=$url with HeaderVersion=$HeaderVersion"

                    $headers = create_auth -HeaderVersion $HeaderVersion -Variables $Variables

                    $Response = Invoke-WebRequest -Method Put -Uri $url -body $Data -Headers $headers

                    new-logentry -Message "Received response from URL=$url with status code $($Response.StatusCode)"

                    return $Response
                }
                Catch
                {
                    throw "Error in Invoke-HttpPut for URL=$url. Error: $($_.Exception.Message)"
                }
            }

            function Invoke-HttpGet
            {
                [CmdletBinding()]
                param
                (
                    [Parameter(Mandatory = $true)]
                    [string]$url,
                    [Parameter(Mandatory = $true)]
                    [string]$HeaderVersion,
                    [Parameter(Mandatory = $true)]
                    [hashtable]$Variables
                )
                Try
                {
                    new-logentry -Message  "Sending HTTP GET request to URL=$url with HeaderVersion=$HeaderVersion"

                    $headers = create_auth -HeaderVersion $HeaderVersion -Variables $Variables

                    $Response = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -UseBasicParsing

                    new-logentry -Message "Received response from URL=$url with status code $($Response.StatusCode)"

                    return $Response
                }
                Catch
                {
                    throw "Error in Invoke-HttpGet for URL=$url. Error: $($_.Exception.Message)"
                }
            }

            function CreateLogDirectory($logPath)
            {
                if (-not (Test-Path -Path $logPath))
                {
                    New-Item -Path $logPath -ItemType Directory | Out-Null

                    Write-Host "Log directory created at: $logPath" -ForegroundColor Green
                }
            }

            function Get-Certificates
            {
                param
                (
                    [Parameter(Mandatory = $true)][hashtable]$Variables,
                    [Parameter(Mandatory = $true)][string]$serial
                )

                $sb = New-Object System.Text.StringBuilder

                [void]$sb.Append('SerialNumber -eq "')

                [void]$sb.Append($serial)

                [void]$sb.Append('"')

                $query = $sb.ToString()

                Add-Type -AssemblyName System.Web

                $encodedString = [System.Uri]::EscapeDataString($query)

                $url = "$($Variables.KEYFACTORAPI)/Certificates?QueryString=$encodedString"

                return ((Invoke-HttpGet -url $url -HeaderVersion 1 -variables $variables).content | ConvertFrom-Json).Id
            }

            function Check_KeyfactorStatus
            {
                param (
                    [Parameter(Mandatory = $true)]
                    [hashtable]$Variables
                )

                $Response = Invoke-HttpGet -Url "$($Variables.KeyfactorAPI)/status/healthcheck" -HeaderVersion 1 -variables $variables

                if ($Response.StatusCode -eq 204)
                {
                    return $true
                }
                else
                {
                    return $false
                }
            }

            function Get-RoleId
            {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $true)]
                    [hashtable]$Variables,
                    [Parameter(Mandatory = $true)]
                    $line
                )

                $sb = New-Object System.Text.StringBuilder

                [void]$sb.Append('name -eq "')

                [void]$sb.Append($($line.role))

                [void]$sb.Append('"')

                $query = $sb.ToString()

                $EncodedQuery = [System.Uri]::EscapeDataString($query)

                return ((Invoke-HttpGet -url "$($Variables.KEYFACTORAPI)/Security/Roles?QueryString=$EncodedQuery" -HeaderVersion 2 -variables $variables).content | ConvertFrom-Json).Id

            }

            function Update-CertificateOwner
            {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $true)]
                    [hashtable]$Variables,
                    [Parameter(Mandatory = $true)]
                    [string]$CertificateId,
                    [Parameter(Mandatory = $true)]
                    [int]$RoleId
                )

                $Body = @{ NewRoleId = $RoleId }

                return Invoke-HttpPut -Url "$($Variables.KEYFACTORAPI)/Certificates/$CertificateId/Owner" -HeaderVersion 1 -Variables $variables -Data ($Body | ConvertTo-Json)
            }

            try {
                # Validate the Keyfactor Command connection
                if (Check_KeyfactorStatus -Variables $Variables)
                {
                    new-logentry -Message  "Validated connection to Keyfactor Command"
                }
                else
                {
                    throw "Failed to validate connection to Keyfactor Command"
                }

                new-logentry -Message  "Getting certificate ID for: $($line.serial)"

                $certificateid = Get-Certificates -Variables $Variables -serial $line.serial

                if (-not ([string]::IsNullOrEmpty($certificateid)))
                {
                    new-logentry -Message "Certificate ID: $certificateid"

                    new-logentry -Message  "Getting role ID for: $($line.Role)"

                    $roleid = Get-RoleId -Variables $Variables -line $line

                    if (-not ([string]::IsNullOrEmpty($roleid)))
                    {
                        new-logentry -Message  "Role ID: $roleid"

                        new-logentry -Message  "Updating certificate with New Role owner: $($line.Role)"

                        $result = Update-CertificateOwner -CertificateId $certificateid -RoleId $roleid -Variables $variables

                        if ($result.StatusCode -eq 204)
                        {
                            new-logentry -Message  "Owner updated: $($line.Role)"
                        }
                        else
                        {
                            new-logentry -Message  "[ERROR]Owner failed to update: $($line.Role)"
                            return
                        }
                    }
                    else
                    {
                        new-logentry -Message  "[ERROR]Role not found: $($line.Role)"
                        return
                    }
                }
                else
                {
                    new-logentry -Message  "[ERROR]Certificate not found: $($line.serial)"
                    return
                }
            }
            catch
            {
                new-logentry -Message "Error processing item $($line.serial): $($_.Exception.Message)"
            }
        }).AddArgument($line).AddArgument($variables).AddArgument($logPath)

        $runspace.RunspacePool = $runspacePool
        $runspaces += [PSCustomObject]@{
            Pipe      = $runspace
            Status    = $runspace.BeginInvoke()
            Item      = $item
        }
    }


    # Wait for all threads to complete
    foreach ($job in $runspaces) {
        $job.Pipe.EndInvoke($job.Status)
        $job.Pipe.Dispose()
    }

    # Close RunspacePool after execution
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
}
catch
{
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red

    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Yellow
}
finally
{
    Write-Host "All tasks completed using multithreading, logs created in $logPath."
}
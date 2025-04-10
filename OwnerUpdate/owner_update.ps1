param (
    [Parameter(Mandatory, Position = 0, HelpMessage = "Path to the CSV file containing the data")]
    [string]$csvPath,
    [Parameter(Mandatory, Position = 1, HelpMessage = "Maximum number of threads to use for runspaces.")]
    [int]$maxThreads,
    [Parameter(Mandatory, Position = 2, HelpMessage = "Hashtable files containing needed variables.")]
    $variableFile
)

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

        write-host "Successfully received Access Token from $($Variables.TOKEN_URL)"
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
        [hashtable]$Data
    )
    Try
    {
        write-host "Sending HTTP Put request to URL=$url with HeaderVersion=$HeaderVersion"

        if (-not $Variables -or -not $Variables.ContainsKey('client_id') -or -not $Variables.ContainsKey('client_secret') -or -not $Variables.ContainsKey('TOKEN_URL')) 
        {
            throw "Error: 'Variables' is null or missing required keys ('client_id', 'client_secret', 'TOKEN_URL')."
        }
        
        if (-not $Data -or -not ($Data -is [hashtable]))
        {
            throw "Error: The 'Data' parameter is either null or not a hashtable."
        }

        $Response = Invoke-WebRequest -Method Put -Uri $url -body $Data -Headers $headers -UseBasicParsing

        $headers = create_auth -HeaderVersion $HeaderVersion -Variables $Variables

        $Response = Invoke-WebRequest -Method Put -Uri $url -body $Data -Headers $headers -UseBasicParsing

        write-host "Received response from URL=$url with status code $($Response.StatusCode)"

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
        write-host "Sending HTTP GET request to URL=$url with HeaderVersion=$HeaderVersion"

        $headers = create_auth -HeaderVersion $HeaderVersion -Variables $Variables

        $Response = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -UseBasicParsing

        write-host "Received response from URL=$url with status code $($Response.StatusCode)"

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
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory = $true)]
		[hashtable]$Variables,
        [Parameter(Mandatory = $true)]
		[string]$line
	)

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.Append('SerialNumber -eq "')

    [void]$sb.Append($($line.certificate))

    [void]$sb.Append('"')

    $query = $sb.ToString()

    Add-Type -AssemblyName System.Web

    $encodedString = [System.Uri]::EscapeDataString($query)

    $url = "$($Variables.keyfactorURL)/Certificates?QueryString=$encodedString"

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
        [string]$line
    )

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.Append('name -eq "')

    [void]$sb.Append($($line.role))

    [void]$sb.Append('"')

    $query = $sb.ToString()

    $EncodedQuery = [System.Uri]::EscapeDataString($query)

    return ((Invoke-HttpGet -url "$($Variables.keyfactorURL)/Security/Roles?QueryString=$EncodedQuery" -HeaderVersion 2 -variables $variables).content | ConvertFrom-Json).Id

}

function Update-CertificateOwner
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$variables,
        [Parameter(Mandatory = $true)]
        [string]$CertificateId,
        [Parameter(Mandatory = $true)]
        [int]$RoleId
    )

    $RequestBody = @{
        NewRoleId = $RoleId
    }

    return Invoke-HttpPut -Url "$($Variables.keyfactorURL)/Certificates/$CertificateId/Owner" -HeaderVersion 1 -Variables $variables -Data ($RequestBody | ConvertTo-Json)
}

function ProcessCsvLine
{
    param(
        [string]$line,
        [string]$scriptPath,
        [hashtable]$variables,
        [runspacepool]$runspacePool,
        [array]$runspaces
    )

    if (-not ($line.PSObject.Properties.Match('certificate') -and $line.PSObject.Properties.Match('role')))
              {
        Write-Host "Skipping malformed or missing data in CSV: $($line | Out-String)" -ForegroundColor Yellow

        return
    }

    Write-Host "Processing: $($line.certificate) with Role: $($line.Role)"

    $runspace = [powershell]::Create().AddScript(
        {
        param (
            $line,
            $variables
        )

        function New-Log
        {
            param (
                [Parameter(Mandatory = $true)]
                [array]$Message,
                [hashtable]$Variables
            )

            $LogFile = $Variables.LOG_FOLDER + "\" + (Get-Date -UFormat "%m-%d-%Y") + ".log"

            $currentDate = (Get-Date -UFormat "%d-%m-%Y")

            $currentTime = (Get-Date -UFormat "%T")

            $Message = $Message -join " "

            "[$currentDate $currentTime] $Message" | Out-File $LogFile -Append
        }

        $output = & {
            New-Log -message "Getting certificate ID for: $($line.certificate)"

            $certificateid = Get-Certificates -Variables $variables -line $line

            if (-not ([string]::IsNullOrEmpty($certificateid)))
            {
                New-Log -message "Certificate ID: $certificateid"

                New-Log -message "Getting role ID for: $($line.Role)"

                $roleid = Get-RoleId -Variables $variables -line $line

                if (-not ([string]::IsNullOrEmpty($roleid)))
                {
                    New-Log -message "Role ID: $roleid"

                    New-Log -message "Updating certificate with New Role owner: $($line.Role)"

                    $result = Update-CertificateOwner -CertificateId $certificateid -RoleId $roleid

                    if ($result.StatusCode -eq 204)
                    {
                        New-Log -message "Owner updated: $($line.Role)"
                    }
                    else
                    {
                        New-Log -message "Owner failed to update: $($line.Role)"
                        return
                    }
                }
                else
                {
                    New-Log -message "Role not found: $($line.Role)"
                    return
                }
            }
            else
            {
                New-Log -message "Certificate not found: $($line.certificate)"
                return
            }
        } *>&1 | Out-String

        $timestamp = (Get-Date -Format "yyyyMMddHHmmssfff")

        $logFilePath = "$($scriptPath)\RunspaceLogs\$($certificate)_$($timestamp).log"

        $output | out-file -FilePath $logFilePath -Append -Encoding UTF8

    }).AddArgument($line).AddArgument($scriptPath).AddArgument($variables).AddArgument($runspacePool).AddArgument($runspaces)

    $runspace.RunspacePool = $runspacePool

    $runspaces.Add([PSCustomObject]@{
        Pipe = $runspace
        Status = $runspace.BeginInvoke()
    }) | Out-Null
}
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
        . $variableFile

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

    # Validate the Keyfactor Command connection
    if (Check_KeyfactorStatus -Variables $Variables)
    {
        write-host  "Validated connection to Keyfactor Command"
    }
    else
    {
        write-host  "Could not validate connection to Keyfactor Command"
        throw "Failed to validate connection to Keyfactor Command"
    }

    # Initialize runspace pool and process CSV lines
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)

    $runspacePool.Open()

    $runspaces = [System.Collections.ArrayList]@()

    foreach ($line in $csvData)
    {
        ProcessCsvLine -line $line -scriptPath $scriptPath -variables $variables -runspacePool $runspacePool -runspaces $runspaces
    }

    # Finalize runspaces
    foreach ($runspace in $runspaces)
    {
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

}
catch
{
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red

    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Yellow
}
finally
{
    # Ensure the runspace pool is closed and disposed
    if ($runspacePool -and $runspacePool.RunspacePoolStateInfo.State -ne [System.Management.Automation.Runspaces.RunspacePoolState]::Closed -and $runspacePool.RunspacePoolStateInfo.State -ne [System.Management.Automation.Runspaces.RunspacePoolState]::Broken)
    {
        $runspacePool.Close()

        $runspacePool.Dispose()
    }
}
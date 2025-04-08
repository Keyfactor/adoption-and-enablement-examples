<#
.SYNOPSIS
    A PowerShell script to migrate certificates from Venafi to Keyfactor Command.

.DESCRIPTION
    This script facilitates the migration of certificates from a Venafi environment to a Keyfactor Command environment.
    It supports multi-threading for efficient processing and includes functionality for environment-specific variable loading,
    authentication, and certificate retrieval and import.

.PARAMETER environment_variables
    Specifies the environment from which variables will be pulled. 
    Possible values are 'Production', 'NonProduction', 'Lab', 'FromFile'.

.PARAMETER MaxThreads
    Specifies the maximum number of threads for the RunspacePool. Default is 10.

.PARAMETER ExportKey
    Specifies whether to export the private key along with the certificate. Default is $false.

.PARAMETER loglevel
    Specifies the logging level for console output. 
    Possible values are 'Info', 'Debug', 'Verbose'. Default is 'Info'.

.PARAMETER variableFile
    Specifies the path and file name of the variable file in Hashtable format, if used.

.FUNCTION load_variables
    Loads environment-specific variables into a hashtable for use throughout the script.

.FUNCTION Check_KeyfactorStatus
    Validates the connection to the Keyfactor Command API by performing a health check.

.FUNCTION Check_VenafiStatus
    Validates the connection to the Venafi API by checking the system version.

.FUNCTION Get-AuthHeaders
    Generates authentication headers for API requests to either Keyfactor or Venafi, depending on the parameters provided.

.FUNCTION Get-Pem
    Retrieves the PEM-formatted certificate from Venafi for a given Distinguished Name (DN).

.FUNCTION Get-VenafiCertificates
    Retrieves a list of certificates from Venafi under a specified parent DN.

.FUNCTION Import-KFCertificate
    Imports a certificate into Keyfactor Command using the provided PEM and thumbprint.

.NOTES
    - This script requires valid client credentials for both Keyfactor and Venafi.
    - Ensure that the required APIs are accessible and the necessary permissions are granted.

.EXAMPLE
    .\Venafi_migration.ps1 -environment_variables Production -MaxThreads 5 -loglevel Debug

    Runs the script in the Production environment with a maximum of 5 threads and debug-level logging.

.EXAMPLE
    .\Venafi_migration.ps1 -environment_variables FromFile -variableFile "C:\path\to\variables.ps1"

    Runs the script using variables loaded from the specified file.

.EXAMPLE
    .\Venafi_migration.ps1 -environment_variables FromFile -variableFile "C:\path\to\variables.ps1" -MaxThreads 15 -ExportKey $true -loglevel Debug

    Runs the script using variables loaded from the specified file with a maximum of 15 threads, debug-level logging and exporting Private Key.
#>
param(
    [Parameter(Mandatory, Position = 0, HelpMessage = "Specify which environment the variables will be pulled from. Possible values are 'Production', 'NonProduction', 'Lab', 'FromFile'.")]
    [ValidateSet("Production", "NonProduction", "Lab", "FromFile")]
    [string]$environment_variables = $null,

    [Parameter(HelpMessage = "Specify the maximum number of threads for the RunspacePool. Default is 10.")]
    [int]$MaxThreads = 10,

    [Parameter(HelpMessage = 'Specify whether to export the private key along with the certificate. Default is $false.')]
    [bool]$ExportKey = $false,

    [Parameter(HelpMessage = "This switch will output logs to the console at various levels. Possible values are 'Info', 'Debug', 'Verbose'. Default is 'Info'.")]
    [ValidateSet("Info", "Debug", "Verbose")]
    [string]$loglevel = 'Info',

    [Parameter(HelpMessage = "Specify if you want to use a variable file. The input is a path and file name of the variable file in Hashtable format.")]
    [string]$variableFile
)

function load_variables
{
    param(
        $environment_variables = $environment_variables
    )

    Write-Debug -Message "Entering function load_variables for $environment_variables environment"

    switch($environment_variables)
    {
        'Production'
        {
            $script:Variables = @{
                KFCLIENT_ID     = '' # Keyfactor Command Client ID
                KFCLIENT_SECRET = '' # Keyfactor Command Client Secret
                KFTOKEN_URL     = '' # Keyfactor Command Token URL
                KFSCOPE         = '' # Keyfactor Command Scope
                KFAUDIENCE      = '' # Keyfactor Command Audience
                KFAPI           = '' # Keyfactor Command API URL 'https://<hostname>/KeyfactorAPI'
                VCLIENT_ID      = '' # Venafi Client ID
                VCLIENT_SECRET  = '' # Venafi Client Secret
                VTOKEN_URL      = '' # Venafi Token URL
                VSCOPE          = '' # Venafi Scope
                VAUDIENCE       = '' # Venafi Audience
                VAPI            = '' # Venafi API URL 'https://<hostname>'
                PARENTDN        = ''   # This is the default parent DN for the certificates to be imported. It should be in the format '\VED\Policy\Certs'
            }
        }
        'NonProduction'
        {
            $script:Variables = @{
                KFCLIENT_ID     = '' # Keyfactor Command Client ID
                KFCLIENT_SECRET = '' # Keyfactor Command Client Secret
                KFTOKEN_URL     = '' # Keyfactor Command Token URL
                KFSCOPE         = '' # Keyfactor Command Scope
                KFAUDIENCE      = '' # Keyfactor Command Audience
                KFAPI           = '' # Keyfactor Command API URL 'https://<hostname>/KeyfactorAPI'
                VCLIENT_ID      = '' # Venafi Client ID
                VCLIENT_SECRET  = '' # Venafi Client Secret
                VTOKEN_URL      = '' # Venafi Token URL
                VSCOPE          = '' # Venafi Scope
                VAUDIENCE       = '' # Venafi Audience
                VAPI            = '' # Venafi API URL 'https://<hostname>'
                PARENTDN        = ''   # This is the default parent DN for the certificates to be imported. It should be in the format '\VED\Policy\Certs'
            }
        }
        'Lab'
        {
            $script:Variables = @{
                KFCLIENT_ID     = '' # Keyfactor Command Client ID
                KFCLIENT_SECRET = '' # Keyfactor Command Client Secret
                KFTOKEN_URL     = '' # Keyfactor Command Token URL
                KFSCOPE         = '' # Keyfactor Command Scope
                KFAUDIENCE      = '' # Keyfactor Command Audience
                KFAPI           = '' # Keyfactor Command API URL 'https://<hostname>/KeyfactorAPI'
                VCLIENT_ID      = '' # Venafi Client ID
                VCLIENT_SECRET  = '' # Venafi Client Secret
                VTOKEN_URL      = '' # Venafi Token URL
                VSCOPE          = '' # Venafi Scope
                VAUDIENCE       = '' # Venafi Audience
                VAPI            = '' # Venafi API URL 'https://<hostname>'
                PARENTDN        = ''   # This is the default parent DN for the certificates to be imported. It should be in the format '\VED\Policy\Certs'
            }
        }
    }
    return $Variables
}

function Check_KeyfactorStatus
{
    param (
        [hashtable]$Variables = $Variables
    )

    $headers = Get-AuthHeaders
    
    $Response = Invoke-WebRequest -Uri "$($Variables.KfAPI)/status/healthcheck" -Headers $headers -Method 'Get' -UseBasicParsing
    
    if ($Response.StatusCode -eq 204) 
    {
        return $true
    } 
    else 
    {
        return $false
    }
}

function Check_VenafiStatus
{
    param (
        [hashtable]$Variables = $Variables
    )

    $headers = Get-AuthHeaders -Venafi $true -Variables $Variables

    $Response = Invoke-WebRequest -Uri "$($Variables.vAPI)/vedsdk/SystemStatus/Version" -Headers $headers -Method 'Get' -UseBasicParsing
    
    if ($Response.StatusCode -eq 200) 
    {
        return $true
    } 
    else 
    {
        return $false
    }
}

    function Get-AuthHeaders {
        param (
            $HeaderVersion = 1,
            [hashtable]$Variables,
            [switch]$Venafi = $false
        )

        $headers = @{'Content-Type' = 'application/x-www-form-urlencoded'}

        if ($Venafi) 
        {
            $body = @{
                'grant_type'    = 'client_credentials'
                'client_id'     = $Variables.vclient_id
                'client_secret' = $Variables.vclient_secret
            }

            if ($Variables.scope) { $body['scope'] = $Variables.vscope }

            if ($Variables.audience) { $body['audience'] = $Variables.vaudience }
    
            try 
            {
                if ([string]::IsNullOrWhiteSpace($Variables.VTOKEN_URL)) {
                    Write-Error -Message "The variable 'VTOKEN_URL' is null or empty. Cannot proceed with the request."
                    return $null
                }
                $accessToken = (Invoke-RestMethod -Method Post -Uri $Variables.VTOKEN_URL -Headers $headers -Body $body).access_token
            } 
            catch 
            {
                Write-Error -message "Error in Get-AuthHeaders: $($_.Exception.Message)"

                return $null
            }

            $headers = @{
                "Content-Type"  = "application/json"
                "Authorization" = "Bearer $accessToken"
            }
        } 
        else 
        {
            $body = @{
                'grant_type'    = 'client_credentials'
                'client_id'     = $Variables.kfclient_id
                'client_secret' = $Variables.kfclient_secret
            }

            if ($Variables.scope) { $body['scope'] = $Variables.kfscope }

                if ([string]::IsNullOrWhiteSpace($Variables.KFTOKEN_URL)) {
                    Write-Error -Message "Error in Get-AuthHeaders: kfTOKEN_URL is null or empty."
                    return $null
                }

                $accessToken = (Invoke-RestMethod -Method Post -Uri $Variables.kfTOKEN_URL -Headers $headers -Body $body).access_token
    
            try 
            {
                $accessToken = (Invoke-RestMethod -Method Post -Uri $Variables.kfTOKEN_URL -Headers $headers -Body $body).access_token
            } 
            catch 
            {
                Write-Error -Message "Error in Get-AuthHeaders: $($_.Exception.Message)"

                return $null
            }

            $headers = @{
                "Content-Type"               = "application/json"
                "Accept"                     = "text/plain"
                "x-keyfactor-requested-with" = "APIClient"
                "x-keyfactor-api-version"    = "$HeaderVersion.0"
                "Authorization"              = "Bearer $accessToken"
            }
        }

        return $headers
    }

    function Get-Pem {
        param (
            [Parameter(Mandatory = $true)]
            [string]$DN,
            [hashtable]$Variables
        )

        $headers = Get-AuthHeaders -Venafi $true -Variables $Variables

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append($Variables.VAPI)
        [void]$sb.Append('/vedsdk/Certificates/Retrieve?CertificateDN=')
        [void]$sb.Append($DN)
        if ($ExportKey)
        {
            [void]$sb.Append('&ExportKey=true')
        }
        else
        {
            [void]$sb.Append('&ExportKey=false')
        }
        $URL = $sb.ToString()

        $response = Invoke-WebRequest -Uri $URL -Headers $Headers -Method Get -UseBasicParsing

        if (!$response) 
        {
            Write-Error -Message "Failed to retrieve PEM for DN=$DN"
        } 

        return $response.Content
    }

    function Get-VenafiCertificates {
        param (
            [hashtable]$Variables
        )

        $headers = Get-AuthHeaders -Venafi $true -Variables $Variables

        $currentDate = Get-Date -Format yyyy-MM-dd

        $EncodedString = [uri]::EscapeDataString($Variables.PARENTDN)

        $response = Invoke-WebRequest -Uri "$($Variables.VAPI)/vedsdk/certificates/?parentdnrecursive=$EncodedString&ValidToGreater=$($currentDate)T00:00:00.0000000Z" -Headers $Headers -Method Get -UseBasicParsing

        if ($response) 
        {

            return ($response.Content | ConvertFrom-Json).Certificates
        } 
        else 
        {
            Write-Error "Failed to retrieve certificate list from $($Variables.PARENTDN)"
        }
        return $null
    }

    function Import-KFCertificate {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Certificate,
            [hashtable]$Variables
        )

        $headers = Get-AuthHeaders -Venafi $false -Variables $Variables

        if (-not $Certificate.ContainsKey('Thumbprint') -or -not $Certificate.ContainsKey('Pem')) {
            Write-Error "The Certificate parameter is missing required fields: 'Thumbprint' or 'Pem'."
            return $null
        }

        $b64Cert = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Certificate['Pem']))

        $response = Invoke-WebRequest -Url "$($Variables.KFAPI)/Certificates/Import" -Headers $headers -Method Post -Body @{ 'Certificate' = $b64Cert }

        if ($response) 
        {
            return ($response.Content | ConvertFrom-Json).ImportStatus
        } 
        else 
        {
            Write-Error "Failed to import certificate."

            return $null
        }
    }

$InformationPreference = 'Continue'

if ($loglevel -eq 'Debug') 
{
    $DebugPreference = 'Continue'
}
else
{
    $DebugPreference = 'SilentlyContinue'
}

if (-not $environment_variables) 
{
if ($variableFile)
{
    if (Test-Path $variableFile)
    {
        try
        {
            . $variableFile
        }
        catch
        {
            throw "Failed to source the variable file. Ensure it is in a valid format and accessible."
        }
    }
    else
    {
        throw "The specified variable file '$variableFile' does not exist."
    }
}
else 
{
    $Script:Variables = load_variables
}

if (!$Variables.kfCLIENT_SECRET)
{
    $CLIENT_SECRET = Read-Host "Please enter your IDP Applications Client Secret for Keyfactor Command"

    $Variables.kfCLIENT_SECRET = $CLIENT_SECRET

    Write-Information -MessageData "Saved Client_Secret in Memory Only"
}

if (!$Variables.vCLIENT_SECRET)
{
    $CLIENT_SECRET = Read-Host "Please enter your IDP Applications Client Secret for Venafi"

    $Variables.vCLIENT_SECRET = $CLIENT_SECRET

    Write-Information -MessageData "Saved Client_Secret in Memory Only"
}

if ($Variables.kfCLIENT_ID)
{
    Write-Debug -message  "Loaded Variables for the '$environment_variables' environment successfully"
}
else
{
    throw  "Could not load Variables for $environment_variables"
}

if (Check_KeyfactorStatus)
{
    Write-Debug -message  "Validated connection to Keyfactor Command"
}
else
{
    throw "Could not validate connection to Keyfactor Command"
}

if (Check_VenafiStatus)
{
    Write-Debug -message  "Validated connection to Venafi"
}
# Create a RunspacePool for multi-threading
# Minimum thread count is set to 1 to ensure at least one thread is always available.
# Maximum thread count is configurable (default is 10) to balance performance and resource usage.
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)  # Minimum 1 thread, configurable maximum threads
    throw  "Could not validate connection to Venafi"
}
$RunspacePool.Open()

# Array to store Runspace objects
$Runspaces = @()

$Certificates = Get-VenafiCertificates -Variables $Variables

# Loop through each certificate and create a runspace for processing
foreach ($certificate in $Certificates) 
{
    $Runspace = [powershell]::Create().AddScript({
        param($certificate, $Variables)

        # Get PEM for the certificate
        $pem = Get-Pem -DN $certificate.DN -Variables $Variables

        if ($pem) 
        {
            # Import the certificate
            $Result = Import-KFCertificate -Certificate @{
                Thumbprint = $certificate.X509.Thumbprint
                Pem = $pem
            } -Variables $Variables

            # Assuming a return value of 2 indicates a successful certificate import.
            if ($Result -eq 2) 
            {
                Write-Output "Certificate imported successfully: $certificate.DN"
            } 
            else 
            {
                Write-Output "Failed to import certificate: $certificate.DN"
            }
        } 
        else 
        {
            Write-Output "Failed to retrieve PEM for certificate: $certificate.DN"
        }

    }).AddArgument($certificate).AddArgument($Variables)

    # Assign the RunspacePool to the PowerShell instance
    $Runspace.RunspacePool = $RunspacePool

    $Runspaces += [PSCustomObject]@{
        Pipeline   = $Runspace
        Status     = $Runspace.BeginInvoke()
    }
}

# Wait for all threads to complete
foreach ($Runspace in $Runspaces) 
{
    try 
    {
        $Runspace.Pipeline.EndInvoke($Runspace.Status)
    } 
    catch 
    {
        Write-Error -Message "Error during EndInvoke: $($_.Exception.Message)"
    }
    finally 
    {
        $Runspace.Pipeline.Dispose()
    }
}

# Close and dispose of the RunspacePool
$RunspacePool.Close()

$RunspacePool.Dispose()

Write-Output "All certificates processed."
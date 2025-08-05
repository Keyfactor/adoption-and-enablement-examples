<#
.SYNOPSIS
    Manages ACME Identifiers via REST API for different environments.

.DESCRIPTION
    This script provides functions to add, remove, and show ACME Identifiers using a REST API.
    It supports multiple environments (Production, Non-Production, Lab) and uses OAuth client credentials for authentication.
    The script allows users to specify the identifier, type, and action to perform.

.PARAMETER environment
    Specifies the target environment. Valid values are "Production", "Non-Production", or "Lab".

.PARAMETER Identifier
    The identifier to add or remove. Optional for 'show' action.

.PARAMETER Type
    The type of identifier. Valid values are "Regex", "Fqdn", "Subnet", or "Wildcard". Optional for 'show' and 'remove' actions.

.PARAMETER action
    The action to perform. Valid values are "add", "remove", or "show".

.FUNCTIONS
    load_variables
        Loads environment-specific variables required for API authentication and requests.

    Get-ACMEHeaders
        Retrieves OAuth token and constructs authorization headers for API requests.

    Add-Identifier
        Adds a new identifier to the ACME system.

    Show-Identifiers
        Retrieves and displays all identifiers from the ACME system.

    Remove-Identifier
        Removes an identifier from the ACME system by its ID.

.EXAMPLE
    .\acme identifiers.ps1 -environment "Production" -Identifier "example.com" -Type "Fqdn" -action "add"
    Adds a new FQDN identifier to the Production environment.

    .\acme identifiers.ps1 -environment "Lab" -action "show"
    Shows all identifiers in the Lab environment.

    .\acme identifiers.ps1 -environment "Non-Production" -action "remove"
    Shows all identifiers and prompts for an ID to remove in the Non-Production environment.

.NOTES
    - Requires valid OAuth credentials and API endpoint configuration.
    - Ensure the CLIENT_ID, CLIENT_SECRET, TOKEN_URL, SCOPE, AUDIENCE, and ACMEDNS variables are set appropriately for each environment.
    - Error handling is implemented for API calls and authentication.

#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Production", "Non-Production", "Lab")]
    [ValidateNotNullOrEmpty()]
    [string]$environment,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()] 
    [string]$Identifier,
    [Parameter(Mandatory = $false)]
    [ValidateSet("Regex", "Fqdn", "Subnet", "Wildcard")]
    [ValidateNotNullOrEmpty()]
    [string]$Type,
    [Parameter(Mandatory = $true)]
    [ValidateSet("add", "remove", "show")]
    [ValidateNotNullOrEmpty()]
    [string]$action,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Secret
)
function load_variables
{
    param(
        $environment = $environment,
        $Secret = $Secret
    )
    Write-Information "Entering function load_variables for $environment environment"
    switch($environment)
    {
        'Production'
        {
            $script:Variables = @{
                CLIENT_ID       = '<YOUR_CLIENT_ID>'
                CLIENT_SECRET   = $Secret
                TOKEN_URL       = '<TOKEN_URL>'
                SCOPE           = '<YOUR_SCOPE>'
                AUDIENCE        = '<YOUR_AUDIENCE>'
                ACMEDNS         = '<CUSTOMER.KEYFACTORPKI.COM>'
            }
        }
        'Non-Production'
        {
            $script:Variables = @{
                CLIENT_ID       = '<YOUR_CLIENT_ID>'
                CLIENT_SECRET   = $Secret
                TOKEN_URL       = '<TOKEN_URL>'
                SCOPE           = '<YOUR_SCOPE>'
                AUDIENCE        = '<YOUR_AUDIENCE>'
                ACMEDNS         = '<CUSTOMER.KEYFACTORPKI.COM>'
            }
        }
        'Lab'
        {
            $script:Variables = @{
                CLIENT_ID       = '<YOUR_CLIENT_ID>'
                CLIENT_SECRET   = $Secret
                TOKEN_URL       = '<TOKEN_URL>'
                SCOPE           = '<YOUR_SCOPE>'
                AUDIENCE        = '<YOUR_AUDIENCE>'
                ACMEDNS         = '<CUSTOMER.KEYFACTORPKI.COM>'
            }
        }
    }
    return $Variables
}
function Get-ACMEHeaders 
{
    $authHeaders = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    $authBody = @{
        'grant_type' = 'client_credentials'
        'client_id'  = $Variables.client_id
        'client_secret' = $Variables.client_secret
    }
    if ($Variables.scope) { $authBody['scope'] = $Variables.scope }
    if ($Variables.audience) { $authBody['audience'] = $Variables.audience }

    try 
    {
        $token = (Invoke-RestMethod -Method Post -Uri $Variables.token_url -Headers $authHeaders -Body $authBody).access_token
        $headers = @{}
        $headers["Authorization"] = "Bearer $token"
    } 
    catch 
    {
        Write-Error -Message "Failed to fetch OAuth token: $($_.Exception.Message)"
        throw
    }
    return $headers
}
function Add-Identifier
{
    try 
    {
        $body = @{
            "Identifier" = $Identifier
            "Type"       = $Type
        }
        $postcall = Invoke-WebRequest -Uri "https://$($Variables.ACMEDNS)/ACME/Identifiers" -Method Post -Headers (Get-ACMEHeaders) -ContentType "application/json" -Body ($body | ConvertTo-Json)
        if ($postcall.StatusCode -eq 200)
        {
            Write-Information "Identifier: $Identifier was added successfully."
        }
        else {
            Write-Error -Message "Failed to add identifier: $($_.Exception.Message)"
        }
    } 
    catch 
    {
        Write-Error "An error occurred: $_"
    }
}
function Show-Identifiers
{
    try 
    {
        $getcall = Invoke-WebRequest -Uri "https://$($Variables.ACMEDNS)/ACME/Identifiers" -Method Get -Headers (Get-ACMEHeaders) -ContentType "application/json"
        if ($getcall.StatusCode -eq 200)
        {
            return $getcall.Content | ConvertFrom-Json
        }
        else {
            Write-Error -Message "Failed to get identifiers: $($_.Exception.Message)"
        }
    } 
    catch 
    {
        Write-Error "An error occurred in get-Identifiers: $($_.Exception.Message)"
    }
}
function Remove-Identifier
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )
    try 
    {
        $deletecall = Invoke-WebRequest -Uri "https://$($Variables.ACMEDNS)/ACME/Identifiers/$id" -Method Delete -Headers (Get-ACMEHeaders) -ContentType "application/json"
        if ($deletecall.StatusCode -eq 204)
        {
            Write-Host "Identifier: $Identifier was removed successfully."
        }
        else {
            Write-Error -Message "Failed to remove identifier: $($_.Exception.Message)"
        }
    } 
    catch 
    {
        Write-Error "An error occurred in remove-Identifier: $($_.Exception.Message)"
    }
}
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

# Test the Get-Headers function by calling it
try 
{
    $Variables = load_variables -environment $environment
    if ($action -eq "add")
    {
        Add-Identifier
    }
    elseif ($action -eq "show")
    {
        Show-Identifiers | Format-Table -AutoSize
    }
    elseif ($action -eq "remove")
    {
        Show-Identifiers | Format-Table -AutoSize
        $Id = Read-Host "Enter the ID of the identifier to remove"
        Remove-Identifier -Id $Id
    }
    else 
    {
        Write-Error "Invalid action specified. Use 'add', 'remove', or 'show'."
    }
} 
catch 
{
    Write-Error "An error occurred: $_"
}
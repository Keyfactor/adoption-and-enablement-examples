<#
.SYNOPSIS
    Retrieves ACME keys from a Keyfactor ACME API endpoint using OAuth authentication.

.DESCRIPTION
    This script authenticates to a Keyfactor ACME API endpoint using OAuth 2.0 client credentials flow.
    It fetches keys based on a specified template and displays them in a formatted table.
    The script requires several mandatory parameters for OAuth and API access.

.PARAMETER client_id
    The OAuth client ID used for authentication.

.PARAMETER client_secret
    The OAuth client secret used for authentication.

.PARAMETER Template
    The name of the template for the keys to be fetched.

.PARAMETER token_url
    The OAuth token endpoint URL.

.PARAMETER scope
    The OAuth scope to request (optional).

.PARAMETER audience
    The OAuth audience to request (optional).

.PARAMETER keyfactorDnsName
    The DNS name of the Keyfactor ACME API endpoint.

.FUNCTION Get-ACMEHeaders
    Authenticates with the OAuth token endpoint and returns the required authorization headers.

.FUNCTION get-keys
    Fetches keys from the Keyfactor ACME API endpoint using the provided template and authentication headers.

.EXAMPLE
    .\acme_keys.ps1 -client_id "my-client-id" -client_secret "my-secret" -Template "MyTemplate" `
        -token_url "https://auth.example.com/oauth/token" -scope "api.read" -audience "https://api.example.com" `
        -keyfactorDnsName "https://keyfactor.example.com/acme"

.NOTES
    - Requires PowerShell 5.1 or later.
    - Ensure network connectivity to the Keyfactor ACME API endpoint and OAuth token URL.
    - Errors during authentication or API calls are reported and will stop execution.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$client_id,
    [Parameter(Mandatory = $true)]
    [string]$client_secret,
    [Parameter(Mandatory = $true)]
    [string]$Template,
    [Parameter(Mandatory = $true)]
    [string]$token_url,
    [Parameter(Mandatory = $true)]
    [string]$scope,
    [Parameter(Mandatory = $true)]
    [string]$audience,
    [Parameter(Mandatory = $true)]
    [string]$keyfactorDnsName
)
$Script:Variables = @{
    # OAuth-specific parameters of oauth acme account
    token_url             = $token_url
    client_id             = $client_id
    client_secret         = $client_secret
    # Optional parameters for OAuth
    scope                 = $scope
    audience              = $audience
    # acme api endpoint
    hostname              = $keyfactorDnsName
    # Template for the keys to be fetched
    Template              = $Template
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
Function Get-keys
{
    try 
    {
        $getcall = Invoke-webrequest -Uri "$($Variables.hostname)/KeyManagement?Template=$($Variables.Template)" -Method Get -Headers (Get-ACMEHeaders) -ContentType "application/json"
        if ($getcall.StatusCode -eq 200)
        {
            return $getcall.Content | ConvertFrom-Json
        }
        else {
            Write-Error -Message "Failed to get keys: $($_.Exception.Message)"
        }
    } 
    catch 
    {
        Write-Error "An error occurred in get-keys: $($_.Exception.Message)"
    }
}


$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
try 
{
    get-keys | Format-Table -AutoSize
}
catch 
{
    Write-Error "An error occurred: $_"
}
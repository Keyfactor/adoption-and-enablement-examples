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
Function get-keys
{
    try 
    {
        $getcall = Invoke-webrequest -Uri "https://$($Variables.hostname)/ACME/KeyManagement?Template=$($Variables.Template)" -Method Get -Headers (Get-ACMEHeaders) -ContentType "application/json"
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
<#
.SYNOPSIS
    Manages ACME claims via REST API for Keyfactor environments.

.DESCRIPTION
    This script provides functions to add, update, remove, and show claims in the ACME API. 
    It supports multiple environments (Production, Non-Production, Lab) and uses OAuth client credentials for authentication.

.PARAMETER ClaimType
    The type of claim to manage (optional).

.PARAMETER ClaimValue
    The value of the claim to manage (optional).

.PARAMETER Roles
    The roles associated with the claim. Must be one of: AccountAdmin, EnrollmentUser, SuperAdmin (optional).

.PARAMETER action
    The action to perform. Must be one of: add, remove, update, show (required).

.PARAMETER Template
    The template associated with the claim (optional).

.PARAMETER environment
    The environment to target. Must be one of: production, Non-Production, Lab (required).

.FUNCTIONS
    load_variables
        Loads environment-specific variables required for API authentication and requests.

    Get-ACMEHeaders
        Retrieves OAuth token and constructs authorization headers for API requests.

    update-claim
        Updates an existing claim by ID.

    add-claim
        Adds a new claim.

    get-claims
        Retrieves all claims from the ACME API.

    remove-claim
        Removes a claim by ID.

.EXAMPLE
    .\acme-claims.ps1 -ClaimType "TypeA" -ClaimValue "Value1" -Roles "AccountAdmin" -action "add" -Template "TemplateA" -environment "production"

.NOTES
    - Requires PowerShell 5.1 or later.
    - Ensure CLIENT_ID, CLIENT_SECRET, TOKEN_URL, SCOPE, AUDIENCE, and ACMEDNS are configured for each environment.
    - Error handling and information logging are implemented throughout the script.
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$ClaimType,
    [Parameter(Mandatory = $false)]
    [string]$ClaimValue,
    [Parameter(Mandatory = $false)]
    [ValidateSet("AccountAdmin", "EnrollmentUser", "SuperAdmin")]
    [string]$Roles,
    [Parameter(Mandatory = $true)]
    [ValidateSet("add", "remove", "update", "show")]
    [ValidateNotNullOrEmpty()]
    [string]$action,
    [Parameter(Mandatory = $false)]
    [string]$Template,
    [Parameter(Mandatory = $true)]
    [ValidateSet("production", "Non-Production", "Lab")]
    [ValidateNotNullOrEmpty()]
    [string]$environment
)
function load_variables
{
    param(
        $environment = $environment
    )
    Write-Information "Entering function load_variables for $environment environment"
    switch($environment)
    {
        'Production'
        {
            $script:Variables = @{
                CLIENT_ID       = '<YOUR_CLIENT_ID>'
                CLIENT_SECRET   = '<YOUR_CLIENT_SECRET>'
                TOKEN_URL       = '<TOKEN_URL>'
                SCOPE           = '<YOUR_SCOPE>'
                AUDIENCE        = '<YOUR_AUDIENCE>'
                ACMEDNS         = '<https://CUSTOMER.KEYFACTORPKI.COM/ACME>'
            }
        }
        'Non-Production'
        {
            $script:Variables = @{
                CLIENT_ID       = '<YOUR_CLIENT_ID>'
                CLIENT_SECRET   = '<YOUR_CLIENT_SECRET>'
                TOKEN_URL       = '<TOKEN_URL>'
                SCOPE           = '<YOUR_SCOPE>'
                AUDIENCE        = '<YOUR_AUDIENCE>'
                ACMEDNS         = '<https://CUSTOMER.KEYFACTORPKI.COM/ACME>'
            }
        }
        'Lab'
        {
            $script:Variables = @{
                CLIENT_ID       = '<YOUR_CLIENT_ID>'
                CLIENT_SECRET   = '<YOUR_CLIENT_SECRET>'
                TOKEN_URL       = '<TOKEN_URL>'
                SCOPE           = '<YOUR_SCOPE>'
                AUDIENCE        = '<YOUR_AUDIENCE>'
                ACMEDNS         = '<https://CUSTOMER.KEYFACTORPKI.COM/ACME>'
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
Function update-claim
{
    param(
        [Parameter(Mandatory = $true)]
        [INT]$Id
    )
    try 
    {
        $body = @{
            "ClaimType"     = $ClaimType
            "ClaimValue"    = $ClaimValue
            "Roles"         = $Roles -split ' '
        }
        if ($Template)
        {
            $body['Template'] = $Template
        }
        $jsonbody = $body | ConvertTo-Json
        $postcall = Invoke-RestMethod -Uri "$($Variables.hostname)/Claims/$Id" -Method Put -Headers (Get-ACMEHeaders) -ContentType "application/json" -body $jsonbody
        if ($postcall.StatusCode -eq 200)
        {
            Write-Information -MessageData "Claim: $($ClaimValue) was updated sucessfully"
        }
    } 
    catch 
    {
        Write-Error "An error occurred in update-claims: $($_)"
    }
}
Function add-claim
{
    try 
    {
        $body = @{
            "ClaimType"     = $ClaimType
            "ClaimValue"    = $ClaimValue
            "Roles"         = $Roles -split ' '
        }
        if ($Template)
        {
            $body['Template'] = $Template
        }
        $jsonbody = $body | ConvertTo-Json
        $postcall = Invoke-RestMethod -Uri "$($Variables.hostname)/Claims" -Method Post -Headers (Get-ACMEHeaders) -ContentType "application/json" -body $jsonbody
        if ($postcall.StatusCode -eq 200)
        {
            Write-Information -MessageData "Claim: $($ClaimValue) was added sucessfully"
        }
    } 
    catch 
    {
        Write-Error "An error occurred in post-claims: $($_)"
    }
}
Function get-claims
{
    try 
    {
        $getcall = Invoke-webrequest -Uri "h$($Variables.hostname)/Claims" -Method Get -Headers (Get-ACMEHeaders) -ContentType "application/json"
        if ($getcall.StatusCode -eq 200)
        {
            return $getcall.Content | ConvertFrom-Json
        }
        else {
            Write-Error -Message "Failed to get claims: $($_.Exception.Message)"
        }
    } 
    catch 
    {
        Write-Error "An error occurred in get-claims: $($_.Exception.Message)"
    }
}

Function remove-claim
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    try 
    {
        $deletecall = Invoke-webrequest -Uri "$($Variables.hostname)/Claims/$id" -Method Delete -Headers (Get-ACMEHeaders) -ContentType "application/json"
        if ($deletecall.StatusCode -eq 200)
        {
            return $deletecall.Content | ConvertFrom-Json
        }
    } 
    catch 
    {
        Write-Error "An error occurred in get-claims: $($_)"
    }
}

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
try 
{
    write-Information "Getting claims..."
    $claims = get-claims
    if ($claims.Count -gt 0)
    {
        if ($action -eq "show")
        {
            Write-Information "Showing all claims:"
            $claims | Format-Table -AutoSize
            return
        }
        $claimExists = $claims | Where-Object { $_.template -eq $Template -and $_.ClaimType -eq $ClaimType -and $_.ClaimValue -eq $ClaimValue }
        if ($claimExists.count -gt 0)
        {
            write-Information "Found existing claim: $($claimExists.ClaimValue) with ID: $($claimExists.id)"
            if ($action -eq "update")
            {
                update-claim -Id $claimExists.id
                Write-Information "Claim: $($ClaimValue) was updated sucessfully"
            }
            elseif ($action -eq "remove")
            {
                remove-claim -Id $claimExists.id
                Write-Information "Claim: $($ClaimValue) was removed sucessfully"
            }
            elseif ($action -eq "add")
            {
                Write-Information "Claim: $($ClaimValue) already exists for this template and claim type."
            }
            else 
            {
                Write-Information "No matching claim found for action: $action"
            }
        }
        elseif ($action -eq "add")
        {
            Write-Information "Claim: $($ClaimValue) does not exist, adding."
            add-claim
            Write-Information "Claim: $($ClaimValue) was added sucessfully"
        }
        else 
        {
            Write-Information "No matching claim found for action: $action"
        }
    }
    else 
    {
        Write-Information "Problems getting claims."
    }
}
catch 
{
    Write-Error "An error occurred: $_"
}
finally 
{
    Write-Information "Script execution completed."
}
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
    [string]$enviroment
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
                ACMEDNS         = '<CUSTOMER.KEYFACTORPKI.COM>'
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
                ACMEDNS         = '<CUSTOMER.KEYFACTORPKI.COM>'
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
        $postcall = Invoke-RestMethod -Uri "https://$($Variables.hostname)/ACME/Claims/$Id" -Method Put -Headers (Get-ACMEHeaders) -ContentType "application/json" -body $jsonbody
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
        $postcall = Invoke-RestMethod -Uri "https://$($Variables.hostname)/ACME/Claims" -Method Post -Headers (Get-ACMEHeaders) -ContentType "application/json" -body $jsonbody
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
        $getcall = Invoke-webrequest -Uri "https://$($Variables.hostname)/ACME/Claims" -Method Get -Headers (Get-ACMEHeaders) -ContentType "application/json"
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
        $deletecall = Invoke-webrequest -Uri "https://$($Variables.hostname)/ACME/Claims/$id" -Method Delete -Headers (Get-ACMEHeaders) -ContentType "application/json"
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
<#
.SYNOPSIS
    Updates a Keyfactor role name and optionally its email, migrates all certificate ownerships to the new role, and deletes the old role.

.DESCRIPTION
    This script automates the process of renaming a Keyfactor role, updating its email address if specified, transferring all certificates owned by the original role to the new role, and finally deleting the old role. It supports multiple environments (Production, NonProduction, Lab) and provides detailed logging at various levels (Info, Debug, Verbose).

.PARAMETER environment
    Specifies which environment the variables will be pulled from. Possible values are 'Production', 'NonProduction', 'Lab'.

.PARAMETER OriginalRoleName
    The name of the existing role that needs to be changed.

.PARAMETER NewRoleName
    The new name for the role.

.PARAMETER NewRoleEmail
    (Optional) The new email address for the role.

.PARAMETER loglevel
    Specifies the log output level. Possible values are 'Info', 'Debug', 'Verbose'. Default is 'Info'.

.FUNCTIONS
    load_variables      - Loads environment-specific variables for API authentication and endpoints.
    Remove-role         - Deletes a role by name.
    Get_Roles           - Retrieves role details by name.
    update-owner        - Updates the owner role of a certificate.
    Get-Certificates    - Retrieves certificates owned by a specific role.
    write-message       - Outputs messages with timestamp and log level.
    get-AuthHeaders     - Retrieves authentication headers for API requests.
    Get_Claims          - Retrieves claim details by claim ID.
    Fetch_AllPages      - Fetches paginated API results.
    Build-Claim         - Constructs a claim object for role update.
    Update-Role         - Updates the role's name, email, and claims.

.EXAMPLE
    .\RoleNameUpdate.ps1 -environment "Production" -OriginalRoleName "OldRole" -NewRoleName "NewRole" -NewRoleEmail "newrole@example.com" -loglevel "Verbose"

.NOTES
    - Requires appropriate API permissions to update roles and certificates.
    - Ensure sensitive information such as client secrets are protected.
    - Use with caution in production environments.
#>

param(
    [Parameter(Mandatory, HelpMessage = "Specify which environment the variables will be pulled from. Possible values are 'Production', 'NonProduction', 'Lab', 'FromFile'.")]
    [ValidateSet("Production", "NonProduction", "Lab")]
    [string]$environment,

    [Parameter(Mandatory, HelpMessage = "Specify the name Role that needs changed.")]
    [string]$OriginalRoleName,

    [Parameter(Mandatory,  HelpMessage = "Specify the new name of the Role.")]
    [string]$NewRoleName,

    [Parameter(HelpMessage = "Specify the new role email address (optional).")]
    [string]$NewRoleEmail = "",

    [Parameter(HelpMessage = "This switch will output logs to the console at various levels. Possible values are 'Info', 'Debug', 'Verbose'. Default is 'Info'.")]
    [ValidateSet("Info", "Debug", "Verbose")]
    [string]$loglevel = 'Info'
)
function load_variables
{
    param(
        $environment = $environment
    )
    write-message -Message "Entering function load_variables for $environment environment" -type Debug
    switch($environment)
    {
        'Production'
        {
            $script:envVariables = @{
                CLIENT_ID       = ''
                CLIENT_SECRET   = ''
                TOKEN_URL       = ''
                SCOPE           = ''
                AUDIENCE        = ''
                KEYFACTORAPI    = ''
            }
        }
        'NonProduction'
        {
            $script:envVariables = @{
                CLIENT_ID       = ''
                CLIENT_SECRET   = ''
                TOKEN_URL       = ''
                SCOPE           = ''
                AUDIENCE        = ''
                KEYFACTORAPI    = ''
            }
        }
        'Lab'
        {
            $script:envVariables = @{
                CLIENT_ID       = 'd424706f-3c5f-453e-8b6e-2be54788bd17'
                CLIENT_SECRET   = ''
                TOKEN_URL       = 'https://auth.pingone.com/3729a543-20bf-44b1-b92b-7ceef13aeecf/as/token'
                SCOPE           = 'APISCOPE'
                AUDIENCE        = 'APISCOPE'
                KEYFACTORAPI    = 'https://boeingoauth.kfdelivery.com/KeyfactorAPI'
            }
        }
    }
    return $script:envVariables
}

function Remove-role
{
    param
    (
        [string]$rolename
    )
    write-message -Message "Entering function Remove-role with RoleName: $rolename" -type Debug
    $roleid = (Get_Roles -rolename $rolename).Id
    $url = "$($script:variables.KeyfactorAPI)/Security/Roles/$roleid"
    write-message -Message "Deleting role with ID: $roleid from URL: $url" -type Debug
    $results = Invoke-WebRequest -Uri $url -Method Delete -UseBasicParsing -Headers (get-AuthHeaders -HeaderVersion 1)
    write-message -Message "Delete role response status code: $($results.StatusCode)" -type Verbose
    return ($results.StatusCode)
}
function Get_Roles
{
    param
    (
        [string]$rolename
    )
    write-message -Message "Entering function Get_Roles with RoleName: $rolename" -type Debug
    $EncodedString = [uri]::EscapeDataString($rolename)
    $url = "$($script:variables.KeyfactorAPI)/Security/Roles?QueryString=Name%20-eq%20%22$EncodedString%22"
    $results = (Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -Headers (get-AuthHeaders -HeaderVersion 2)).Content | ConvertFrom-Json
    if ($results.Count -eq 1)
    {
        $roleid = $results[0].Id
        $url = "$($script:variables.KeyfactorAPI)/Security/Roles/$roleid"
        $finalresults = (Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -Headers (get-AuthHeaders -HeaderVersion 2)).Content | ConvertFrom-Json
        write-message -Message "Role $rolename found with ID: $roleid" -type Verbose
        write-message -Message "Role details: $($finalresults | ConvertTo-Json -Depth 10)" -type Verbose
        return $finalresults
    }
    else 
    {
        write-message -Message "[Get_Roles]Role name $rolename returned $($results.Count) results. Please specify a unique role name or use RoleID." -type Error
    }
}

function update-owner
{
    param(
        [STRING]$id,
        [STRING]$NewRoleName
    )
    write-message -message "Entering function update-owner with Certificate ID: $id to new owner role: $NewRoleName" -type Debug
    $result = Invoke-WebRequest "$($Variables.KEYFACTORAPI)/certificates/$id/owner" -Method Put -Headers (get-AuthHeaders -HeaderVersion 1) -body ((@{'NewRoleName' = $NewRoleName} | ConvertTo-Json))
    write-message -message "Update owner response status code: $($result.StatusCode)" -type Verbose
    return $result
}

function Get-Certificates
{
    param
    (
        [string]$rolename
    )
    write-message -Message "Entering function Get-Certificates with RoleName: $rolename" -type Debug
    $EncodedString = [uri]::EscapeDataString($rolename)
    $Url = "$($variables.keyfactorapi)/Certificates?IncludeRevoked=true&IncludeExpired=true&QueryString=OwnerRoleName%20-eq%20%22$EncodedString%22&PageReturned=1"
    $pageurl = "$($variables.keyfactorapi)/Certificates?IncludeRevoked=true&IncludeExpired=true&QueryString=OwnerRoleName%20-eq%20%22$EncodedString%22&collectionId=0&includeLocations=false&includeMetadata=false&ReturnLimit=100&PageReturned="
    return (Fetch_AllPages -Url $Url -PageUrl $pageurl -HeaderVersion 1).Content | ConvertFrom-Json
}
function write-message
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$Message,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Error", "Warning", "Debug", "Verbose")]
        $type
    )

    $currentDate = (Get-Date -UFormat "%d-%m-%Y")
    $currentTime = (Get-Date -UFormat "%T")
    $Message = $Message -join " "
    switch($Type)
    {
        "Info" { Write-Information -MessageData "[$currentDate $currentTime] $Message" -InformationAction Continue }
        "Error" { Write-Warning -Message "[$currentDate $currentTime] $Message" -WarningAction  Stop}
        "Warning" {Write-Warning -Message "[$currentDate $currentTime] $Message" -WarningAction Continue}
        "Debug" {Write-debug -Message "[$currentDate $currentTime] $Message"}
        "Verbose" {Write-Verbose -Message "[$currentDate $currentTime] $Message"}
    }
}

function get-AuthHeaders
{
    param (
        $HeaderVersion = 1
    )
    $headers = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    $body = @{
        'grant_type' = 'client_credentials'
        'client_id' = $($script:variables.client_id)
        'client_secret' = $($script:variables.client_secret)
    }
    if ($script:variables.scope){$body['scope'] = $script:variables.scope}
    if ($script:variables.audience){$body['audience'] = $script:variables.audience}

    write-message -Message "calling $($script:variables.TOKEN_URL)" -type Verbose
    $access_token = (Invoke-RestMethod -Method Post -Uri $script:variables.TOKEN_URL -Headers $headers -Body $body).access_token
    if (-not $access_token)
    {
        write-message -Message "Failed to retrieve access token from $($script:variables.TOKEN_URL)" -type Error
        throw "Failed to retrieve access token from $($script:variables.TOKEN_URL)"
    }
    write-message -Message "Sucessfully recieved Access Token from $($script:variables.TOKEN_URL)" -type Verbose
    return @{
        "content-type"                  = "application/json"
        "accept"                        = "text/plain"
        "x-keyfactor-requested-with"    = "APIClient"
        "x-keyfactor-api-version"       = "$HeaderVersion.0"
        "Authorization"                 = "Bearer $access_token"
    }
}

function Get_Claims
{
    param (
        [INT]$Claimid
    )
    write-message -Message "Entering function Get_Claims with ClaimId: $ClaimId" -type Debug
    $Url = "$($variables.keyfactorapi)/Security/Claims/$ClaimId"
    $result = Invoke-WebRequest $Url -Headers (get-AuthHeaders -HeaderVersion 1) -Method Get -UseBasicParsing
    write-message -Message "Get_Claims response status code: $($result.StatusCode)" -type Verbose
    write-message -Message "Get_Claims response content: $($result.Content)" -type Verbose
    return $result.Content | ConvertFrom-Json
}

function Fetch_AllPages 
{
    param (
        [string]$Url,
        [string]$PageUrl,
        [string]$HeaderVersion
    )
    write-message -Message "Entering function Fetch_AllPages" -type Debug
    $TotalResults = @()
    $InitialResponse = Invoke-WebRequest "$Url" -Method Get -Headers (get-AuthHeaders -HeaderVersion $HeaderVersion) -UseBasicParsing
    $TotalCount = $InitialResponse.Headers["x-total-count"]
    write-message -Message "Total count of items to fetch: $TotalCount" -type Verbose
    if ($TotalCount -lt 50) {
        write-message -Message "Total count is less than page size limit. Returning initial response." -type Verbose
        return $InitialResponse
    }

    $TotalPages = [math]::Ceiling($TotalCount / 50)
    write-message -Message "Total pages to fetch: $TotalPages" -type Verbose
    write-message -Message "Initiating paginated fetch from URL=$Url with PageUrl=$PageUrl" -type Verbose

    for ($CurrentPage = 1; $CurrentPage -le $TotalPages; $CurrentPage++) {
        write-message -Message "Fetching page $CurrentPage/$TotalPages from URL=$PageUrl" -type Verbose
        $FullUrl = "$PageUrl$CurrentPage"
        $Response = (Invoke-HttpGet -Url $FullUrl -HeaderVersion $HeaderVersion)
        $TotalResults += $Response.Content | ConvertFrom-Json
    }
    write-message -Message "Finished fetching all pages. Total results: $($TotalResults.Count)" -type Verbose
    return $TotalResults
}
function Build-Claim 
{
    param(
        [string]$ClaimId
    )
    write-message -Message "Entering function Build-Claim with ClaimId: $ClaimId" -type Debug
    # Fetch claim data and convert from JSON
    $claimData = Get_Claims -ClaimId $ClaimId
    if (-not $claimData) {
        throw "Claim with ID $ClaimId could not be retrieved."
    }

    # Map claim type
    switch ($claimData.ClaimType) {
        'user'        { $claimData.ClaimType = 0 }
        'group'       { $claimData.ClaimType = 1 }
        'computer'    { $claimData.ClaimType = 2 }
        'OAuthOid'    { $claimData.ClaimType = 3 }
        'OAuthRole'   { $claimData.ClaimType = 4 }
        'OAuthSubject'{ $claimData.ClaimType = 5 }
        'OAuthClientId'{ $claimData.ClaimType = 6 }
        default       { throw "Unknown claim type: $($claimData.ClaimType)" }
    }
    
    $result = @{
        "ClaimType"                    = $claimData.ClaimType
        "ClaimValue"                   = $claimData.ClaimValue
        "ProviderAuthenticationScheme" = $claimData.Provider.AuthenticationScheme
        "Description"                  = $claimData.Description
    }
    write-message -Message "Built claim data: $($result | ConvertTo-Json -Depth 10)" -type Verbose
    return $result
}
function Update-Role
{
    param(
        [string]$OriginalRoleName,
        [string]$NewRoleName,
        [string]$NewRoleEmail = ""
    )
    write-message -Message "Entering function Update-Role to update role from $OriginalRoleName to $NewRoleName with email: $NewRoleEmail" -type Debug
    # Fetch the role data
    $roleData = Get_Roles -Rolename $OriginalRoleName
    if (-not $roleData) {
        throw "Role with name $OriginalRoleName could not be retrieved."
    }

    # Loop through existing claims and add the new claim
    $newclaims = @()
    foreach ($claim in $roleData.Claims) 
    {
        $newClaim = Build-Claim -ClaimId $claim.Id
        $newclaims += $newClaim
    }
    $roleData.Claims = @()
    Add-Member -InputObject $roleData -NotePropertyName "Claims" -NotePropertyValue @($newclaims) -Force
    $roleData.Name = $NewRoleName
    if ($NewRoleEmail -ne "") 
    {
        $roleData.Emailaddress = $NewRoleEmail
    }
    write-message -Message "Prepared role data for update: $($roleData | ConvertTo-Json -Depth 10)" -type Verbose
    # Prepare API call (uncomment when you need to actually send the request)
    $url = "$($script:variables.KeyfactorAPI)/security/Roles"
    $results = Invoke-WebRequest $url -Method Post -Body ($roleData | ConvertTo-Json -Depth 10) -Headers (get-AuthHeaders -HeaderVersion 2) -UseBasicParsing
    write-message -Message "Update role response status code: $($results.StatusCode)" -type Verbose
    return $results.Content | ConvertFrom-Json
}
    if ($loglevel -eq 'Debug') 
{
    $DebugPreference = 'Continue'
    $VerbosePreference = 'SilentlyContinue'
} 
elseif ($loglevel -eq 'Verbose') 
{
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
} 
else
{
    $DebugPreference = 'SilentlyContinue'
    $VerbosePreference = 'SilentlyContinue'
}
$variables = load_variables -environment $environment
if (-not $variables['client_secret'] -or $variables['client_secret'] -eq '') 
{
    $variables['client_secret'] = Read-Host -Prompt "Enter the client secret for environment $environment" -AsSecureString
    $variables['client_secret'] = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($variables['client_secret']))
    if (-not $variables['client_secret'] -or $variables['client_secret'] -eq '') 
    {
        write-message -Message "Client secret is required. Exiting script." -type Error
        exit
    }
}
write-message -Message "Updating role from: $OriginalRoleName to newrole: $NewRoleName" -type Info
$Result = Update-Role -OriginalRoleName $OriginalRoleName -NewRoleName $NewRoleName -NewRoleEmail $NewRoleEmail
if (-not $Result) 
{
    write-message -Message "Role update failed. Exiting script." -type Error
    exit
}
write-message -Message "Updating certificates with owner role: $newrolename" -type Info
$certificates = Get-Certificates -rolename $OriginalRoleName
if ($certificates.Count -eq 0)
{
    write-message -Message "No certificates found for role $OriginalRoleName. Exiting script." -type Info
    exit
}
foreach ($cert in $certificates) 
{
    write-message -Message "Updating certificate ID $($cert.Id) owner to $NewRoleName" -type Info
    $updateResult = update-owner -id $cert.Id -NewRoleName $NewRoleName
    if ($updateResult.StatusCode -eq 204) 
    {
        write-message -Message "Successfully updated certificate ID $($cert.Id)." -type Info
    } 
    else 
    {
        write-message -Message "Failed to update certificate ID $($cert.Id). Status code: $($updateResult.StatusCode)" -type Info
    }
}
if ((Get-Certificates -rolename $OriginalRoleName).count -gt 0) 
{
    write-message -Message "Some certificates still reference the old role $OriginalRoleName. Please investigate." -type Warning
} 
else
{
    $result = Remove-role -rolename $OriginalRoleName
    if ($result -eq 204) 
    {
        write-message -Message "Successfully deleted old role $OriginalRoleName" -type Info
    } 
    else 
    {
        write-message -Message "Failed to delete old role $OriginalRoleName. Status code: $result" -type Error
    }
    write-message -Message "Role update completed successfully. New Role ID: $Result" -type Info
} 
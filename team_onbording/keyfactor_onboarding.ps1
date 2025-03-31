<#
.SYNOPSIS
    A script to automatically create Keyfactor collections, roles, and set permissions for the collections in the roles.
    Optionally, you can define a claim to be added to the role and specify additional roles for the claim.

.DESCRIPTION
    This script allows you to set up environments, specify role details, and manage claims. 
    It supports multiple environments ('Production', 'NonProduction', 'Lab', 'FromFile') and offers options for debugging, 
    role customization, and OAuth-related claims.

.PARAMETER environment_variables
    Specify the environment where the variables will be pulled from. 
    Allowed values are 'Production', 'NonProduction', 'Lab', or 'FromFile'. This is a mandatory parameter.

.PARAMETER role_name
    Specify the name of the role and collection to be created. This is a mandatory parameter.

.PARAMETER role_email
    Specify the email address associated with the role. This is an optional parameter.

.PARAMETER Claim
    Specify the claim value to be added to the role. This is an optional parameter.

.PARAMETER Claim_Type
    Specify the type of the claim. Allowed values are 'OAuthRole' and 'OAuthSubject'. 
    This parameter is required if a claim is specified.

.PARAMETER Force
    Force the script to continue even if certain validations fail, such as missing email addresses. 
    This is an optional switch parameter.

.PARAMETER loglevel
    Specify the logging level for the script. Allowed values are 'Info', 'Debug', or 'Verbose'. 
    Defaults to 'Info'.

.PARAMETER RoleOnly
    Specify this switch to create only the role without creating collections or claims. This is an optional switch parameter.

.PARAMETER variableFile
    Specify the path to a variable file in Hashtable format to load additional variables. This is an optional parameter.

.EXAMPLE
    \keyfactor_onboarding.ps1 -environment Production -role_name a1 -role_email a1@domain.com -Claim a1group -Claim_Type OAuthRole
    Runs the script in the 'Production' environment for the role 'a1' and will create a collection and role with the specified claim and type.

.EXAMPLE
    .\keyfactor_onboarding.ps1 -environment Production -role_name a2 -role_email a2@domain.com -Claim a2group -Claim_Type OAuthRole -loglevel Debug
    Runs the script in the 'Production' environment for the role 'a2' and will create a collection and role with the specified claim and type and 
    have more log output with a log level of Debug.

.EXAMPLE
    .\keyfactor_onboarding.ps1 -environment Production -role_name a4 -role_email a4@domain.com
    Runs the script in the 'Production' environment for the role 'a4' and will create a collection and role only.

.EXAMPLE
    .\keyfactor_onboarding.ps1 -environment Production -role_name a5
    Runs the script in the 'Production' environment for the role 'a5' and will create a collection and role only. Because no email was provided, 
    it will ask you if you want to proceed.

.EXAMPLE
    .\keyfactor_onboarding.ps1 -environment Production -role_name a6 -Force
    Runs the script in the 'Production' environment for the role 'a6' and will create a collection and role only. Because no email was provided, 
    but the force switch was used, it will not ask you if you want to proceed.

.EXAMPLE
    .\keyfactor_onboarding.ps1 -environment FromFile -role_name a8 -Force -variableFile "C:\Users\jhowland\OneDrive - Keyfactor\Documents\github\adoption-and-enablement-examples\role_onbording\Variables.ps1"
    Runs the script in the 'Production' environment for the role 'a8' and will create a collection and role only. Because no email was provided, 
    but the force switch was used, it will not ask you if you want to proceed. The variables will be pulled from the file provided in the variableFile parameter.

.NOTES
    Author: Jeremy Howland
    Date: 2025-03-28
    Version: 1.0
    This script follows PowerShell best practices for modularity, logging, and debugging.
#>

param(
    [Parameter(Mandatory, Position = 0, HelpMessage = "Specify which environment the variables will be pulled from. Possible values are 'Production', 'NonProduction', 'Lab', 'FromFile'.")]
    [ValidateSet("Production", "NonProduction", "Lab", "FromFile")]
    [string]$environment_variables = $null,

    [Parameter(Mandatory, Position = 1, HelpMessage = "Specify the name of the role and collection.")]
    $role_name,

    [Parameter(HelpMessage = "Specify the role email address (optional).")]
    $role_email = $null,

    [Parameter(HelpMessage = "Specify the claim information (optional).")]
    $Claim = $null,

    [Parameter(HelpMessage = "Specify the claim type. Allowed values are 'OAuthRole' and 'OAuthSubject'.")]
    [ValidateSet("OAuthRole", "OAuthSubject")]
    [string]$Claim_Type = $null,

    [Parameter(HelpMessage = "Specify if the email validation check should suspend the script or continue.")]
    [switch]$Force = $false,

    [Parameter(HelpMessage = "This switch will output logs to the console at various levels. Possible values are 'Info', 'Debug', 'Verbose'. Default is 'Info'.")]
    [ValidateSet("Info", "Debug", "Verbose")]
    [string]$loglevel = 'Info',

    [Parameter(HelpMessage = "This switch will create the role only.")]
    [switch]$RoleOnly = $false,

    [Parameter(HelpMessage = "Specify if you want to use a variable file. The input is a path and file name of the variable file in Hashtable format.")]
    [string]$variableFile
)

function load_variables
{
    param(
        $environment_variables = $environment_variables
    )
    write-message -Message "Entering function load_variables for $environment_variables environment" -type Debug
    $script:staticVariables = @{
        COLLECTION_DESCRIPTION   = ""
        ROLE_DESCRIPTION         = ""
        CLAIM_SCHEME             = ""
        CLAIM_DESCRIPTION        = ""
        INCLUDE_EMAIL_IN_ROLE   = $false
        ROLE_PERMISSIONS = @{
            1 = "/portal/read/"
            2 = "/certificates/collections/revoke/"
            3 = "/certificates/collections/private_key/read/"
            4 = "/certificates/collections/metadata/modify/"
            5 = "/certificates/collections/change_owner/"
            6 = "/certificates/collections/read/"
        }
    }
    switch($environment_variables)
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
                ADDITIONAL_COLLECTIONS = @{
                    1 = ""
                    2 = ""
                    3 = ""
                }
                ADDITIONAL_ROLES = @{
                    1 = ""
                    2 = ""
                }
            }
        }
        'Non-Production'
        {
            $script:envVariables = @{
                CLIENT_ID       = ''
                CLIENT_SECRET   = ''
                TOKEN_URL       = ''
                SCOPE           = ''
                AUDIENCE        = ''
                KEYFACTORAPI    = ''
                ADDITIONAL_COLLECTIONS = @{
                    1 = ""
                    2 = ""
                    3 = ""
                }
                ADDITIONAL_ROLES = @{
                    1 = ""
                    2 = ""
                }
            }
        }
        'Lab'
        {
            $script:envVariables = @{
                CLIENT_ID       = ''
                CLIENT_SECRET   = ''
                TOKEN_URL       = ''
                SCOPE           = ''
                AUDIENCE        = ''
                KEYFACTORAPI    = ''
                ADDITIONAL_COLLECTIONS = @{
                    1 = ""
                    2 = ""
                    3 = ""
                }
                ADDITIONAL_ROLES = @{
                    1 = ""
                    2 = ""
                }
            }
        }
    }
    return $envVariables + $staticVariables
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
        [Parameter(Mandatory = $false)]
        [hashtable]$Variables = $Variables
    )
    Try
    {
        write-message -Message "Sending HTTP GET request to URL=$url with HeaderVersion=$HeaderVersion" -type Verbose
        $headers = create_auth -HeaderVersion $HeaderVersion
        $Response = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -UseBasicParsing
        write-message -Message "Received response from URL=$url with status code $($Response.StatusCode)" -type Verbose
        return $Response
    }
    Catch
    {
        write-message -Message "Error in Invoke-HttpGet for URL=$url. Error: $($_.Exception.Message)" -type Error
    }
}

function Fetch_AllPages {
    param (
        [string]$Url,
        [string]$PageUrl,
        [hashtable]$Variables = $Variables,
        [string]$HeaderVersion
    )
    write-message -Message "Initiating paginated fetch from URL=$Url with PageUrl=$PageUrl" -type Verbose
    $TotalResults = @()
    $InitialResponse = Invoke-HttpGet -Url "$Url`1" -HeaderVersion $HeaderVersion
    $TotalCount = $InitialResponse.Headers["x-total-count"]
    if ($TotalCount -lt 50) {
        write-message -Message "Total count is less than page size limit. Returning initial response." -type Verbose
        return $InitialResponse
    }
    else 
    {
        write-message -Message "Total pages to fetch: $TotalPages" -type Verbose
    }

    $TotalPages = [math]::Ceiling($TotalCount / 50)

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
function Invoke-HttpPost
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$url,
        [Parameter(Mandatory = $false)]
        [string]$HeaderVersion,
        $Variables = $Variables,
        [Parameter(Mandatory = $false)]
        $body
    )
    $headers = create_auth -HeaderVersion $HeaderVersion
    return Invoke-WebRequest -Method Post -Uri $url -Headers $headers -Body $body -UseBasicParsing
}

function Invoke-Http_Put {
    param (
        [string]$Url,
        [string]$HeaderVersion,
        $Data,
        [hashtable]$Variables = $Variables
    )
    $headers = create_auth -HeaderVersion $HeaderVersion
    return Invoke-RestMethod -Uri $Url -Headers $Headers -Method Put -Body $Data
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
        "Info" { Write-Information -MessageData "[$currentDate $currentTime] $Message"}
        "Error" { Write-Warning -Message "[$currentDate $currentTime] $Message" -WarningAction  Stop}
        "Warning" {Write-Warning -Message "[$currentDate $currentTime] $Message" -WarningAction Continue}
        "Debug" {Write-debug -Message "[$currentDate $currentTime] $Message"}
        "Verbose" {Write-Verbose -Message "[$currentDate $currentTime] $Message"}
    }
}
function Check_KeyfactorStatus
{
    param (
        [hashtable]$Variables = $Variables
    )
    $HeaderVersion = '1'
    $Url = "$($Variables.KeyfactorAPI)/status/healthcheck"
    $Response = Invoke-HttpGet -Url $Url -HeaderVersion $HeaderVersion
    if ($Response.StatusCode -eq 204) {
        return $true
    } else {
        return $false
    }
}

function create_auth
{
    param (
        $HeaderVersion = 1,
        [hashtable]$Variables = $Variables
    )
    $headers = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    $body = @{
        'grant_type' = 'client_credentials'
        'client_id' = $($Variables.client_id)
        'client_secret' = $($Variables.client_secret)
    }
    if ($variables.scope){$body['scope'] = $variables.scope}
    if ($variables.audience){$body['audience'] = $variables.audience}

    try
    {
        $access_token = (Invoke-RestMethod -Method Post -Uri $Variables.TOKEN_URL -Headers $headers -Body $body).access_token
        write-message -Message "Sucessfully recieved Access Token from $($Variables.TOKEN_URL)" -type Verbose
    }
    catch
    {
        write-message -Message "Error in create_auth: $($_.Exception.Message)" -type Error
    }
    return @{
        "content-type"                  = "application/json"
        "accept"                        = "text/plain"
        "x-keyfactor-requested-with"    = "APIClient"
        "x-keyfactor-api-version"       = "$HeaderVersion.0"
        "Authorization"                 = "Bearer $access_token"
    }
}

function process_collections
{
    param
    (
        [Parameter(Mandatory = $false)]
        [hashtable]$Variables = $Variables,
        [Parameter(Mandatory = $true)]
        [string]$role_name,
        [Parameter(Mandatory = $false)]
        [string]$role_email = $null
    )

    write-message -Message "checking if collection exists for role: $role_name" -type Info

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('Name -eq "')
    [void]$sb.Append($role_name)
    [void]$sb.Append('"')
    $query = $sb.ToString()

    write-message -Message "search Query is: $query" -type Debug

    $Collectionid = (get_collections -Query $query).id

    if ($Collectionid)
    {
        write-message -Message "collection for $role_name exists with ID: $CollectionId." -type Info
    }
    else 
    {
        write-message -Message "collection for $role_name does not exists, creating ..." -type Info

        $CollectionId = (New_Collection -role_name $role_name -role_email $role_email).Id

        write-message -Message "collection for $role_name was created with collection id: $CollectionId." -type Info
    }
    return $Collectionid
}

function Get_Collections
{
    [CmdletBinding()]
    param
    (
        [hashtable]$Variables = $Variables,
        [string]$Query = $null,
        [string]$Name = $null
    )

    if (-not ([string]::IsNullOrEmpty($Name)))
    {
        Add-Type -AssemblyName System.Web
        $encodedString = [System.Uri]::EscapeDataString($Name)
        $url = "$($Variables.KeyfactorAPI)/CertificateCollections/$encodedString"
        return (Invoke-HttpGet -url $url -HeaderVersion 1).content | ConvertFrom-Json
    }
    elseif (-not ([string]::IsNullOrEmpty($Query)))
    {
        Add-Type -AssemblyName System.Web
        $encodedString = [System.Uri]::EscapeDataString($Query)
        $url = "$($Variables.KeyfactorAPI)/CertificateCollections?QueryString=$encodedString&ReturnLimit="
        $pageurl = "$($Variables.KeyfactorAPI)/CertificateCollections?QueryString=$encodedString&PageReturned="
        return (Fetch_AllPages -url $url -pageurl $pageurl -HeaderVersion 1) | ConvertFrom-Json
    }
}

function New_Collection
{
    [CmdletBinding()]
    param
    (
        [hashtable]$Variables = $Variables,
        [Parameter(Mandatory = $true)]
        $role_name,
        $role_email = $null
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('OwnerRoleName -eq "')
    [void]$sb.Append($role_name)
    if ($Variables.Include_email_in_role)
    {
        [void]$sb.Append(' (')
        [void]$sb.Append($role_email)
        [void]$sb.Append(')')
    }
    [void]$sb.Append('"')
    $query = $sb.ToString()

    write-message -Message "Creating Collection with Query: $Query and Name: $role_name" -type Debug

    $Body = @{
        Name = $role_name
        Description = $Variables.COLLECTION_DESCRIPTION
        Query = $Query
        Favorite = $true
        DuplicationField = 2
    }

    $url = "$($Variables.KeyfactorAPI)/CertificateCollections"
    return (Invoke-HttpPost -url $url -HeaderVersion 1 -body ($body | ConvertTo-Json)).content | ConvertFrom-Json
}

function process_roles
{
    param
    (
        [hashtable]$Variables = $Variables,
        [string]$role_name = $null,
        $collection = $null,
        $role_email = $null
    )

    write-message -Message "checking if a role exists for $role_name" -type Info
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('Name -eq "')
    [void]$sb.Append($role_name)
    if ($Variables.Include_email_in_role)
    {
        [void]$sb.Append(' (')
        [void]$sb.Append($role_email)
        [void]$sb.Append(')')
    }
    [void]$sb.Append('"')
    $query = $sb.ToString()

    write-message -Message "search Query is: $query" -type Debug

    $roleid = ((get_roles -Query $query) | ConvertFrom-Json).id

    if ($roleid)
    {
        write-message -Message "role for $role_name exists with RoleId: $roleid." -type Info
    }
    else
    {
        write-message -Message "role for $role_name does not exists, creating." -type Info
        $roleid = (New-Role -role_name $role_name -collection $collectionid -role_email $role_email).Id
        write-message -Message "role for $role_name was created with RoleID: $roleid." -type Info
    }
    return $roleid
}

function Get_Roles
{
    [CmdletBinding()]
    param
    (
        [hashtable]$Variables = $Variables,
        $roleid = $null,
        $query = $null
    )

    if (-not ([string]::IsNullOrEmpty($roleid)))
    {
        $url = "$($Variables.KeyfactorAPI)/Security/Roles/$roleid"
        return Invoke-HttpGet -url $url -HeaderVersion 2
    }
    elseif (-not ([string]::IsNullOrEmpty($Query)))
    {
        Add-Type -AssemblyName System.Web
        $encodedString = [System.Uri]::EscapeDataString($Query)
        $url = "$($Variables.KeyfactorAPI)/Security/Roles?QueryString=$encodedString&ReturnLimit="
        $pageurl = "$($Variables.KeyfactorAPI)/Security/Roles?QueryString=$encodedString&PageReturned="
        return Fetch_AllPages -url $url -pageurl $pageurl -HeaderVersion 2
    }
}

function New-Role
{
    [CmdletBinding()]
    param
    (
        [hashtable]$Variables = $Variables,
        [Parameter(Mandatory = $true)]
        $role_name,
        [Parameter(Mandatory = $false)]
        [INT]$collectionid = $null,
        [Parameter(Mandatory = $false)]
        $role_email = $null,
        [Parameter(Mandatory = $false)]
        $permissionset = $null
    )
    function Get-PermissionsetId
    {
        [CmdletBinding()]
        param (
            [hashtable]$Variables = $Variables
        )

        $url = "$($Variables.keyfactorapi)/permissionsets?ReturnLimit="
        $pageurl = "$($Variables.keyfactorapi)/permissionsets?PageReturned="
        return (Fetch_AllPages -url $url -pageurl $pageurl -HeaderVersion 1) | ConvertFrom-Json
    }

    $Collectionids = New-Object System.Collections.ArrayList
    $permissions = New-Object System.Collections.ArrayList
    foreach ($additional in $Variables.ADDITIONAL_COLLECTIONS.values)
    {
        $acollectionid = (Get_Collections -Name $additional).Id
        $Collectionids.Add($acollectionid) | Out-Null
    }
    $Collectionids.Add($collectionid) | Out-Null
    foreach($permission in $Variables.ROLE_PERMISSIONS.Values)
    {
        if ($permission -match "Collection")
        {
            foreach ($id in $Collectionids)
            {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.Append($permission)
                [void]$sb.Append($id)
                [void]$sb.Append("/")
                $join = $sb.ToString()
                $permissions.Add($join) | Out-Null
            }
        }
        else {
            $permissions.Add($permission) | Out-Null
        }
    }

    if ([string]::IsNullOrEmpty($permissionset))
    {
        $psname = "global"
        $permissionset = Get-PermissionsetId
        $permissionset = $permissionset | Where-Object { $_.name -like "$psname" }
        $permissionset = $permissionset.id
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($role_name)
    if ($Variables.Include_email_in_role)
    {
        [void]$sb.Append(' (')
        [void]$sb.Append($role_email)
        [void]$sb.Append(')')
    }
    $name = $sb.ToString()

    write-message -Message "Creating role with Name: $name" -type Debug

    $Body = @{
        Name = $name
        Description = $variables.ROLE_DESCRIPTION
        EmailAddress = $role_email
        PermissionSetId = $permissionset
        Permissions = $permissions
    }

    $url = "$($Variables.KeyfactorAPI)/security/roles"
    return (Invoke-HttpPost -url $url -HeaderVersion 2 -body ($body | ConvertTo-Json)).content | ConvertFrom-Json
}

function process_claims
{
    param
    (
        [hashtable]$Variables = $Variables,
        $claim = $null,
        $claimtype
    )

    write-message -Message "checking if a claim exists for $claim" -type Info

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('ClaimValue -eq "')
    [void]$sb.Append($claim)
    [void]$sb.Append('"')
    $query = $sb.ToString()

    write-message -Message "search Query is: $query" -type Debug

    $claimid = ((Get_Claims -Query $query).content | Convertfrom-Json).Id
    if ($claimid)
    {
        write-message -Message "claim for $claim exists with ClaimID: $claimid" -type Info
    }
    else
    {
        write-message -Message "claim for $claim does not exists, creating." -type Info
        $claimid = ((New-claim -claimvalue $claim -claimtype $claimtype).content | Convertfrom-Json).Id
        write-message -Message "claim for $claim was created with ClaimID: $claimid." -type Info
    }
    return $claimid
}

function Get_Claims
{
    param (
        [hashtable]$Variables = $Variables,
        [string]$Query = $null,
        [INT]$Claimid = $null
    )
    if (-not ([string]::IsNullOrEmpty($Query)))
    {
        $EncodedString = [uri]::EscapeDataString($Query)
        $Url = "$($Variables.keyfactorapi)/Security/Claims?QueryString=$EncodedString&ReturnLimit="
        $PageUrl = "$($Variables.keyfactorapi)/Security/Claims?QueryString=$EncodedString&PageReturned="
        return Fetch_AllPages -Url $Url -PageUrl $PageUrl -HeaderVersion 1
    }
    elseif (-not ([string]::IsNullOrEmpty($ClaimId)))
    {
        $Url = "$($Variables.keyfactorapi)/Security/Claims/$ClaimId"
        return Invoke-HttpGet -Url $Url -HeaderVersion 1
    }
}

function New-Claim
{
    param
    (
        [hashtable]$Variables = $Variables,
        [Parameter(Mandatory = $true)]
        [ValidateSet('OAuthRole', 'OAuthSubject')]
        [String]$claimtype,
        [Parameter(Mandatory = $true)]
        [String]$claimvalue
    )

    switch ($claimtype)
    {
        'OAuthRole' { $type = 4; Break }
        'OAuthSubject' { $type = 5; Break }
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($Variables.CLAIM_DESCRIPTION)
    [void]$sb.Append($claimvalue)
    $description = $sb.ToString()


    $body = @{
        "ClaimType"				       = $type
        "ClaimValue"				   = $claimvalue
        "ProviderAuthenticationScheme" = $Variables.CLAIM_SCHEME
        "Description"				   = $description
    }

    $url = "$($Variables.keyfactorapi)/security/claims"
    return Invoke-HttpPost -url $url -HeaderVersion 1 -body ($body | ConvertTo-JSON)
}

function Update-RoleClaim
{
    param(
        [hashtable]$Variables = $Variables,
        [string]$RoleId,
        [string]$ClaimId
    )

    # Helper function: Build a claim object
    function Build-Claim {
        param(
            [hashtable]$Variables = $Variables,
            [string]$ClaimId
        )
        # Fetch claim data and convert from JSON
        $claimData = (Get_Claims -ClaimId $ClaimId).content | ConvertFrom-Json
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

        # Return the constructed claim object
        return @{
            "ClaimType"                    = $claimData.ClaimType
            "ClaimValue"                   = $claimData.ClaimValue
            "ProviderAuthenticationScheme" = $claimData.Provider.AuthenticationScheme
            "Description"                  = $claimData.Description
        }
    }

    # Check if the RoleId is valid
    if ([string]::IsNullOrEmpty($RoleId)) {
        throw "RoleId cannot be null or empty."
    }

    # Fetch the role data
    $roleData = (Get_Roles -RoleId $RoleId).content | ConvertFrom-Json
    if (-not $roleData) {
        throw "Role with ID $RoleId could not be retrieved."
    }

    # Check if the claim exists in the role
    if ($ClaimId -in $roleData.Claims.id) {
        write-message -message  "Claim with ID $ClaimId already exists in Role $RoleId." -type Info
        return $roleData
    } else {
        write-message -message  "Claim with ID $ClaimId does not exist in Role $RoleId, creating it." -type Info

        # Loop through existing claims and add the new claim
        $newclaims = @()
        foreach ($claim in $roleData.Claims) {
            $newClaim = Build-Claim -Variables $Variables -ClaimId $Claim.Id
            $newclaims += $newClaim
        }
        $newClaim = Build-Claim -Variables $Variables -ClaimId $ClaimId
        $newclaims += $newClaim
        $roleData.Claims = @()
        Add-Member -InputObject $roleData -NotePropertyName "Claims" -NotePropertyValue @($newclaims) -Force

        # Prepare API call (uncomment when you need to actually send the request)
        $url = "$($Variables.KeyfactorAPI)/security/Roles"
        return Invoke-Http_Put -Url $url -HeaderVersion 2 -Data ($roleData | ConvertTo-Json -Depth 10)
    }
}

function process_additional_roles
{
    param(
        [hashtable]$Variables = $Variables,
        $role,
        [string]$ClaimId
    )
    write-message -Message "adding claim to temlate roles" -type Info
    if ((-not [string]::IsNullOrEmpty($role)))
    {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('name -eq "')
        [void]$sb.Append($role)
        [void]$sb.Append('"')
        $query = $sb.ToString()
        $roleid = ((get_roles -Query $query).content | Convertfrom-Json).Id
        $rolevalidation = Update-RoleClaim -RoleId $roleid -ClaimId $ClaimId
        if ($rolevalidation)
        {
            write-message -Message "added $claimid to role: $role" -type Info
        }
        else {
            write-message -Message "ERROR Could not add $claimid to role: $role" -type Info
        }
    }
}

# Main script execution starts here
try {
    $WarningPreference = 'Stop'
    $InformationPreference = 'Continue'

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

    if (-not $environment_variables) 
    {
        throw "environment is a required parameter. Allowed values are 'Production', 'NonProduction', 'Lab', 'FromFile."
    }

    if (-not $role_name) 
    {
        throw "role_name is a required parameter."
    }

    if ($Claim -and -not $Claim_Type) 
    {
        throw "Claim_Type is required when Claim is specified. Allowed values are 'OAuthRole' and 'OAuthSubject'."
    }

    write-message -Message "Script execution started with parameters environment=$environment_variables, role_name=$role_name" -type Info
    write-message -Message "Received parameters: environment=$environment_variables, role_name=$role_name, role_email=$role_email, Claim=$Claim, Claim_Type=$Claim_Type" -type Debug
    
    if ($variableFile)
    {
        . $variableFile
        write-message -Message "Loaded variables from $variableFile" -type Debug
    }
    else 
    {
        $Script:Variables = load_variables
    }
    
    if (!$Variables.CLIENT_SECRET)
    {
        if ($force)
        {
            write-message -Message "Can not use 'Force' paramater when client_Secret is not in the environment Varibles or the Variables File" -type Error
        }
        $CLIENT_SECRET = Read-Host "Please enter your IDP Applications Client Secret"
        $Variables.CLIENT_SECRET = $CLIENT_SECRET
        write-message -Message "Saved Client_Secret in Memory Only" -type Info
    }
    if ($Variables.CLIENT_ID)
    {
        write-message -message  "Loaded Variables for $environment_variables environment" -type Debug
    }
    else
    {
        write-message -message  "Could not load Variables for $environment_variables" -type Error
    }

    if (Check_KeyfactorStatus)
    {
        write-message -message  "Validated connection to Keyfactor Command" -type Debug
    }
    else
    {
        write-message -message  "Could not validate connection to Keyfactor Command" -type Error
    }

    if ($CollectionOnly) { $RoleOnly = $false; $claimOnly = $false }
    if ($RoleOnly) { $CollectionOnly = $false; $claimOnly = $false }
    if ($claimOnly) { $CollectionOnly = $false; $RoleOnly = $false }

    if ($RoleOnly)
    {
        write-message -Message "RoleOnly is set to true, skipping collection creation" -type Debug
        if ($role_name)
        {
            if ($Variables.Include_email_in_role)
            {
                if (!$role_email)
                {
                    write-message -Message "'Include_email_in_role' variable is set to true but no email was provided" -type Error
                }
            }
            elseif (!$role_email)
            {
                    if ($force)
                    {
                        write-message -Message "'Include_email_in_role' variable is set to false and no email was provided" -type Debug
                    }
                    else
                    {
                        Write-Warning -Message "No Email Given, The Keyfactor Security Role will not have an email associated with it" -WarningAction Inquire
                    }
            }
    
            write-message -message  "Processing Role for: $role_name" -type Info
            if ((process_roles -role_name $role_name -role_email $role_email -collection $collectionid).id)
            {
                write-message -message  "Role for $role_name was created" -type Info
            }
        }
    }
    else 
    {
        if ($role_name)
        {
            if ($Variables.Include_email_in_role)
            {
                if (!$role_email)
                {
                    write-message -Message "'Include_email_in_role' variable is set to true but no email was provided" -type Error
                }
            }
            elseif (!$role_email)
            {
                if ($force)
                {
                    write-message -Message "'Include_email_in_role' variable is set to false and no email was provided" -type Debug
                }
                else
                {
                    Write-Warning -Message "No Email Given, The Keyfactor Security Role will not have an email associated with it" -WarningAction Inquire
                }
            }

            write-message -message  "Processing role: $role_name" -type Info

            $collectionid = process_collections -role_name $role_name -role_email $role_email
            $roleid = process_roles -role_name $role_name -role_email $role_email -collection $collectionid
            if ($claim)
            {
                $claimid = process_claims -claim $claim -roleid $roleid -claimtype $Claim_Type
                $roleupdate = Update-RoleClaim -Roleid $roleid -Claimid $claimid
                if ($roleupdate.id)
                {
                    write-message -message  "Role updated with role: $role_name" -type Info
                }
                foreach ($role in $Variables.additional_roles.values)
                {
                    process_additional_roles -ClaimId $claimid -role $role
                }
            }
        }
        else
        {
            write-message -message  "Process Stopped, No role_name given" -type Error
        }
    }
    write-message -Message "Script execution completed successfully" -type Info
}
catch
{
    $_
}
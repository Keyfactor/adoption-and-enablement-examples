$script:loglevel = 'Info' # Allowed values are 'Info', 'Debug', 'Verbose'
$script:environment = 'Lab' # Allowed values are 'Production', 'NonProduction', 'Lab'
$script:dryrun = $false  # Set to $true to enable dry run mode (no changes made), $false to disable
$script:logfolder = ".\" # Folder to store log files
$script:retentiondays = 30 # Number of days to retain log files
function Get-Variables
{
    param(
        $environment = $script:environment
    )
    try
    {
        write-message -Message "Entering function Get-Variables for $environment environment" -type Debug
        $staticVariables = @{
            entra_all_users_group   = "jhowlandtest"
            ROLE_DESCRIPTION        = "This is the role description for the named role"
            CLAIM_DESCRIPTION       = "This is the claim description for the named claim"
        }
        switch($environment)
        {
            'Production'
            {
                $envVariables = @{
                    Entra_client_id     = ''
                    Entra_client_secret = ''
                    Entra_token_url     = ''
                    CLIENT_ID           = ''
                    CLIENT_SECRET       = ''
                    TOKEN_URL           = ''
                    SCOPE               = ''
                    AUDIENCE            = ''
                    KEYFACTORAPI        = 'https://customer.keyfactorpki.com/KeyfactorAPI'
                    CLAIM_SCHEME        = ''
                    PermissionSetName   = ''
                }
            }
            'NonProduction'
            {
                $envVariables = @{
                    Entra_client_id     = ''
                    Entra_client_secret = ''
                    Entra_token_url     = ''
                    CLIENT_ID           = ''
                    CLIENT_SECRET       = ''
                    TOKEN_URL           = ''
                    SCOPE               = ''
                    AUDIENCE            = ''
                    KEYFACTORAPI        = 'https://customer.keyfactorpki.com/KeyfactorAPI'
                    CLAIM_SCHEME        = ''
                    PermissionSetName   = ''
                }
            }
            'Lab'
            {
                $envVariables = @{
                    Entra_client_id     = ''
                    Entra_client_secret = ''
                    Entra_token_url     = ''
                    CLIENT_ID           = ''
                    CLIENT_SECRET       = ''
                    TOKEN_URL           = ''
                    SCOPE               = ''
                    AUDIENCE            = ''
                    KEYFACTORAPI        = 'https://customer.keyfactorpki.com/KeyfactorAPI'
                    CLAIM_SCHEME        = ''
                    PermissionSetName   = ''
                }
            }
        }
        return $envVariables + $staticVariables
    }
    catch
    {
        write-message -Message "Error in Get-Variables: $($_.Exception.Message)" -type Error
    }
}

function Remove-Logs {
    [CmdletBinding()]
    param (
        [string]$script:logfolder = ".\",
        [int]$script:retentiondays = 30
    )

    if (Test-Path -Path $script:logfolder) 
    {
        $oldLogs = Get-ChildItem -Path $script:logfolder -Filter "provisioning_*.log" -File |
                   Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$script:retentiondays) }

        if ($oldLogs) 
        {
            $oldLogs | Remove-Item -Force
            Write-Host "Removed $($oldLogs.Count) log file(s) older than $script:retentiondays days from $script:logfolder"
        } 
        else 
        {
            Write-Host "No log files older than $script:retentiondays days found in $script:logfolder"
        }
    } else {
        Write-Host "Log folder not found: $script:logfolder"
    }
}
function Write-Message 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Error", "Warning", "Debug", "Verbose")]
        [string]$Type,

        [Parameter()]
        [ValidateSet("Info", "Error", "Warning", "Debug", "Verbose")]
        [string]$loglevel = $script:loglevel,

        [Parameter()]
        [string]$LogPath = ".\provisioning_$(Get-Date -UFormat '%m-%d-%Y').log"
    )

    $currentDate = (Get-Date -UFormat "%m-%d-%Y")
    $currentTime = (Get-Date -UFormat "%T")
    $messageText = $Message -join " "
    $logEntry = "[$currentDate $currentTime] [$Type] $messageText"

    switch ($Type) {
        "Info"    { Write-Information -MessageData $logEntry }
        "Error"   { Write-Warning -Message $logEntry -ErrorAction Stop }
        "Warning" { Write-Warning -Message $logEntry -WarningAction Continue }
        "Debug"   { if ($loglevel -eq 'Debug')   { Write-Debug -Message $logEntry } }
        "Verbose" { if ($loglevel -eq 'Verbose') { Write-Verbose -Message $logEntry } }
    }

    if ($Type -in @("Info", "Error", "Warning") -or $Type -eq $loglevel) {
        $logEntry | Out-File -FilePath $LogPath -Append
    }
}
function Get-KeyfactorStatus
{
    write-message -Message "Entering function Get-KeyfactorStatus" -type Debug
    $Url = "$($script:Variables.KeyfactorAPI)/status/endpoints"
    write-message -Message "Checking Keyfactor Command Status at $Url" -type Debug
    $Response = Invoke-WebRequest -Uri $Url -Method Get -Headers (Get-Headers) -TimeoutSec 30
    write-message -Message "Leaving function Get-KeyfactorStatus" -type Debug
    if ($Response) {
        return $true
    } else {
        return $false
    }
}
function Get-Headers
{
    param (
        $HeaderVersion = 1
    )
    $headers = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    $body = @{
        'grant_type' = 'client_credentials'
        'client_id' = $($script:Variables.client_id)
        'client_secret' = $($script:Variables.client_secret)
    }
    if ($script:Variables.scope){$body['scope'] = $script:Variables.scope}
    if ($script:Variables.audience){$body['audience'] = $script:Variables.audience}

    try
    {
        $access_token = (Invoke-RestMethod -Method Post -Uri $script:Variables.TOKEN_URL -Headers $headers -Body $body).access_token
        write-message -Message "Successfully received Access Token from $($script:Variables.TOKEN_URL)" -type Verbose
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
function Get-EntraGroupTransitiveMembers 
{
    param (
        [string]$GroupName
    )

    try {
        write-message -Message "Entering function Get-EntraGroupTransitiveMembers" -type Debug
        $tokenBody = @{
            grant_type    = 'client_credentials'
            client_id     = $script:Variables["entra_client_id"]
            client_secret = $script:Variables["entra_client_secret"]
            scope         = 'https://graph.microsoft.com/.default'
        }

        $tokenResp = Invoke-RestMethod -Method Post -Uri $script:Variables["entra_token_url"] `
            -Headers @{ "Content-Type" = "application/x-www-form-urlencoded" } `
            -Body $tokenBody -TimeoutSec 30

        $accessToken = $tokenResp.access_token
        $headers = @{
            "Authorization" = "Bearer $accessToken"
            "Content-Type"  = "application/json"
        }

        $searchUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$GroupName'"
        $searchResp = Invoke-RestMethod -Method Get -Uri $searchUrl -Headers $headers -TimeoutSec 30

        if (-not $searchResp.value) {
            write-message -Message "Group '$GroupName' not found" -type Warning
            return @()
        }

        $groupId = $searchResp.value[0].id
        $groups = @()
        $membersUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/transitiveMembers"

        while ($membersUrl) {
            $membersResp = Invoke-RestMethod -Method Get -Uri $membersUrl -Headers $headers -TimeoutSec 30
            $groupMembers = $membersResp.value | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
            $groups += $groupMembers
            $membersUrl = $membersResp.'@odata.nextLink'
        }

        write-message -Message "Total transitive group members retrieved: $($groups.Count)" -Type Info
        write-message -Message "Leaving function Get-EntraGroupTransitiveMembers" -type Debug
        return $groups
    }
    catch {
        write-message -Message "Error occurred: $_" -type Error
        return @()
    }
}
function get-role
{
    param (
        [int]$id
    )
    write-message -Message "Entering function get-role" -type Debug
    $Url = "$($script:Variables.KeyfactorAPI)/Security/roles/$id"
    write-message -Message "Getting Role from Keyfactor Command at $Url" -type Debug
    $Response = Invoke-WebRequest -Uri $Url -Method Get -Headers (Get-Headers -HeaderVersion 2) -TimeoutSec 30
    if ($Response.StatusCode -ne 200)
    {
        write-message -Message "Error retrieving role ID $($id): $($Response.StatusCode) $($Response.StatusDescription)" -type Error
        return $null
    }
    $role = $Response.Content | ConvertFrom-Json
    write-message -Message "Leaving function get-role for role ID $id" -type Debug
    return $role
}
function get-roles
{
    try {
        write-message -Message "Entering function get-roles" -type Debug
        $Url = "$($script:Variables.KeyfactorAPI)/Security/roles?ReturnLimit=100&PageReturned="
        write-message -Message "Getting Roles from Keyfactor Command at $($Url)1" -type Debug
        $Response = Invoke-WebRequest -Uri "$($Url)1" -Method Get -Headers (Get-Headers -HeaderVersion 2) -TimeoutSec 30
        if ($Response.StatusCode -ne 200)
        {
            write-message -Message "Error retrieving roles: $($Response.StatusCode) $($Response.StatusDescription)" -type Error
            return $null
        }
        [INT]$totalRoles = $response.Headers.'x-total-count'[0]
        write-message -Message "Retrieved $totalRoles roles from Keyfactor Command" -type Debug
        if ($totalRoles -le 100)
        {
            write-message -Message "100 or fewer roles detected, gathering all roles in single request." -type Debug
            $allRoles = $Response.Content | ConvertFrom-Json
        }
        else
        {
            write-message -Message "More than 100 roles detected, gathering all roles." -type Debug
            $allRoles = @()
            $allRoles += $Response.Content | ConvertFrom-Json
            $pages = [math]::Ceiling($totalRoles / 100)
            write-message -Message "Total pages to retrieve: $pages" -type Debug
            for ($i = 2; $i -le $pages; $i++)
            {
                $newurl = "$($url)$i"
                write-message -Message "Getting Roles from Keyfactor Command at $newurl" -type Debug
                $Response = Invoke-WebRequest -Uri $newurl -Method Get -Headers (Get-Headers -HeaderVersion 2) -TimeoutSec 30
                if ($Response.StatusCode -ne 200)
                {
                    write-message -Message "Error retrieving roles: $($Response.StatusCode)" -type Error
                    return $null
                }
                $allRoles += $Response.Content | ConvertFrom-Json
            }
        }
        write-message -Message "Total roles retrieved: $($allRoles.Count)" -type Debug
        write-message -Message "Fetching detailed information for each role." -type Debug
        $roles = @()
        foreach ($role in $allRoles)
        {
            $role = get-role -id $role.Id
            $roles += $role
        }
        write-message -Message "Leaving function get-roles" -type Debug
        return $roles
    }
    catch {
        write-message -Message "Error occurred in get-roles: $_" -type Error
        return $null
    }
}
function get-claims
{
    try {
        write-message -Message "Entering function get-claims" -type Debug
        $Url = "$($script:Variables.KeyfactorAPI)/Security/Claims?ReturnLimit=100&PageReturned="
        write-message -Message "Getting Claims from Keyfactor Command at $($Url)1" -type Debug
        $Response = Invoke-WebRequest -Uri "$($Url)1" -Method Get -Headers (Get-Headers) -TimeoutSec 30
        if ($Response.StatusCode -ne 200)
        {
            write-message -Message "Error retrieving claims: $($Response.StatusCode) $($Response.StatusDescription)" -type Error
            return $null
        }
        [INT]$totalClaims = $response.Headers.'x-total-count'[0]
        write-message -Message "Retrieved $totalClaims claims from Keyfactor Command" -type Debug
        if ($totalClaims -le 100)
        {
            write-message -Message "100 or fewer claims detected, gathering all claims in single request." -type Debug
            return $Response.Content | ConvertFrom-Json
        }
        else
        {
            write-message -Message "More than 100 claims detected, gathering all claims." -type Debug
            $allClaims = @()
            $allClaims += $Response.Content | ConvertFrom-Json
            $pages = [math]::Ceiling($totalClaims / 100)
            write-message -Message "Total pages to retrieve: $pages" -type Debug
            for ($i = 2; $i -le $pages; $i++)
            {
                $newurl = "$($url)$i"
                write-message -Message "Getting Claims from Keyfactor Command at $newurl" -type Debug
                $Response = Invoke-WebRequest -Uri $newurl -Method Get -Headers (Get-Headers) -TimeoutSec 30
                if ($Response.StatusCode -ne 200)
                {
                    write-message -Message "Error retrieving claims: $($Response.StatusCode)" -type Error
                    return $null
                }
                $allClaims += $Response.Content | ConvertFrom-Json
            }
        }
        write-message -Message "Total claims retrieved: $($allClaims.Count)" -type Debug
        write-message -Message "Leaving function get-claims" -type Debug
        return $allClaims
    }
    catch {
        write-message -Message "Error occurred in get-claims: $_" -type Error
        return $null
    }
}
function new-claim
{
    param (
        [string]$claimName
    )
    write-message -Message "Entering function create-claim for claim '$claimName'" -type Debug
    if ($script:dryrun)
    {
        write-message -Message "Dry run enabled, skipping claim creation." -type Info
        write-message -Message "Leaving function create-claim for claim '$claimName'" -type Debug
        return $null
    }
    $Url = "$($script:Variables.KeyfactorAPI)/Security/Claims"
    $Body = @{
        ClaimValue     = $claimName
        Description    = $script:Variables.CLAIM_DESCRIPTION
        ProviderAuthenticationScheme    = $script:Variables.CLAIM_SCHEME
        ClaimType      = "oauthrole"
    }
    write-message -Message "Creating Claim with body: $($Body | ConvertTo-Json -Depth 10)" -type Verbose
    write-message -Message "Creating Claim in Keyfactor Command at $Url" -type Debug
    $Response = Invoke-WebRequest -Uri $Url -Method Post -Headers (Get-Headers) -Body ($Body | ConvertTo-Json -Depth 10) -TimeoutSec 30
    if ($Response.StatusCode -ne 200)
    {
        write-message -Message "Error creating claim '$claimName': $($Response.StatusCode) $($Response.StatusDescription)" -type Error
        return $null
    }
    $claim = $Response.Content | ConvertFrom-Json
    write-message -Message "Successfully created claim '$claimName' with ID $($claim.Id)" -type Info
    write-message -Message "Leaving function create-claim for claim '$claimName'" -type Debug
    return $claim
}
function get-permissionset_id
{
    write-message -Message "Entering function get-permissionsetid for Permission Set '$($script:Variables.PermissionSetName)'" -type Debug
    $Url = "$($script:Variables.KeyfactorAPI)/PermissionSets?QueryString=name%20-eq%20%22$($script:Variables.PermissionSetName)%22"
    write-message -Message "Getting Permission Sets from Keyfactor Command at $Url" -type Debug
    $Response = Invoke-WebRequest -Uri $Url -Method Get -Headers (Get-Headers) -TimeoutSec 30
    if ($Response.StatusCode -ne 200)
    {
        write-message -Message "Error retrieving permission sets: $($Response.StatusCode) $($Response.StatusDescription)" -type Error
        return $null
    }
    $permissionSet = $Response.Content | ConvertFrom-Json

    if ($permissionSet)
    {
        write-message -Message "Found Permission Set '$($script:Variables.PermissionSetName)' with ID $($permissionSet.Id)" -type Info
        write-message -Message "Leaving function get-permissionsetid for Permission Set '$($script:Variables.PermissionSetName)'" -type Debug
        return $permissionSet.Id
    }
    write-message -Message "Permission Set '$($script:Variables.PermissionSetName)' not found" -type Error
    write-message -Message "Leaving function get-permissionsetid for Permission Set '$($script:Variables.PermissionSetName)'" -type Debug
    return $null
}
function New-Role 
{
    param (
        [string]$RoleName,
        [string]$Mail,
        $Claim
    )
    try
    {
        Write-Message -Message "Entering function New-Role for role '$RoleName'" -Type Debug
        Write-Host "Creating role '$RoleName' with email '$Mail' and claim '$($Claim.ClaimValue)'"
        if ($script:dryrun) {
            Write-Message -Message "Dry run enabled, skipping role creation." -Type Info
            Write-Message -Message "Leaving function New-Role for role '$RoleName'" -Type Debug
            return $null
        }
        $Body = @{
            Name            = $RoleName
            Description     = $RoleName
            EmailAddress    = $Mail
            PermissionSetId = Get-PermissionSet_Id
            Permissions     = @()
            Claims          = @(
                [PSCustomObject]@{
                    ClaimType                    = 4
                    ClaimValue                   = $Claim.ClaimValue
                    ProviderAuthenticationScheme = $Claim.Provider.AuthenticationScheme
                    Description                  = $Claim.Description
                }
            )
        }
        write-message -Message "Creating Role with body: $($Body | ConvertTo-Json -Depth 10)" -type Verbose
        Write-Message -Message "Creating Role in Keyfactor Command" -Type Debug

        $Url = "$($script:Variables.KeyfactorAPI)/Security/roles"
        $Response = Invoke-WebRequest -Uri $Url -Method Post -Headers (Get-Headers -HeaderVersion 2) -Body ($Body | ConvertTo-Json -Depth 10) -TimeoutSec 30
        write-message -Message "Role creation response received: $($Response.StatusCode) $($Response.StatusDescription)" -Type Debug
        if ($Response.StatusCode -ne 200) {
            Write-Message -Message "Error creating role '$RoleName': $($Response.StatusCode) $($Response.StatusDescription)" -Type Error
            Write-Message -Message "Leaving function New-Role for role '$RoleName'" -Type Debug
            return $null
        }

        Write-Message -Message "Leaving function New-Role for role '$RoleName'" -Type Debug
        return $Response.Content | ConvertFrom-Json
    }
    catch {
        Write-Message -Message "Exception occurred while creating role '$RoleName': $_" -Type Error
        return $null
    }
}
function confirm-role
{
    param (
        $Role,
        $Member,
        $Claim
    )
    try
    {
        write-message -Message "Entering function confirm-role for role '$($Role.Name)'" -type Debug
        $D_Update = $false
        $C_Update = $false
        $M_Update = $false
        if (-not $Role.Description)
        {
            write-message -Message "Role '$($Role.Name)' is missing Description." -type Debug
            $D_Update = $true
        }
        if ($role.mail -ne $Member.mail)
        {
            write-message -Message "Role '$($Role.Name)' has mismatched email. Role email: '$($Role.mail)', Member email: '$($Member.mail)'" -type Debug
            $M_Update = $true
        }
        if ($Role.Claims.ClaimValue -notcontains $Claim.ClaimValue)
        {
            write-message -Message "Role '$($Role.Name)' is missing Claim '$($Claim.ClaimValue)'." -type Debug
            $C_Update = $true
        }
        write-message -Message "Leaving function confirm-role for role '$($Role.Name)'" -type Debug
        return @{
            DescriptionUpdate = $D_Update
            ClaimUpdate       = $C_Update
            MailUpdate        = $M_Update
        }
    }
    catch
    {
        write-message -Message "Error in confirm-role: $($_.Exception.Message)" -type Error
    }
}
function update-role
{
    param (
        $Role,
        $Member,
        $Claim,
        $Updates
    )
    function Build-Claim {
        param(
            $Claim
        )
        write-message -Message "Building claim object for claim type '$($Claim.ClaimType)'" -type Debug
        switch ($Claim.ClaimType) {
            'user'        { $Claim.ClaimType = 0 }
            'group'       { $Claim.ClaimType = 1 }
            'computer'    { $Claim.ClaimType = 2 }
            'OAuthOid'    { $Claim.ClaimType = 3 }
            'OAuthRole'   { $Claim.ClaimType = 4 }
            'OAuthSubject'{ $Claim.ClaimType = 5 }
            'OAuthClientId'{ $Claim.ClaimType = 6 }
            default       { throw "Unknown claim type: $($Claim.ClaimType)" }
        }

        # Return the constructed claim object
        return @{
            "ClaimType"                    = $Claim.ClaimType
            "ClaimValue"                   = $Claim.ClaimValue
            "ProviderAuthenticationScheme" = $Claim.Provider.AuthenticationScheme
            "Description"                  = $Claim.Description
        }
    }
    write-message -Message "Entering function update-role for role '$($Role.Name)'" -type Debug
    if ($script:dryrun)
    {
        write-message -Message "Dry run enabled, skipping role update." -type Info
        write-message -Message "Leaving function update-role for role '$($Role.Name)'" -type Debug
        return $null
    }
    if ($role.Claims)
    {
        $updatedClaims = @()
        foreach ($existingClaim in $Role.Claims)
        {
            $updatedClaims += Build-Claim -Claim $existingClaim
        }
        $Role.Claims = $updatedClaims
    }
    if ($updates.ClaimUpdate)
    {
        $Role.Claims += [PSCustomObject]@{
            ClaimType                    = 4
            ClaimValue                   = $Claim.ClaimValue
            ProviderAuthenticationScheme = $Claim.Provider.AuthenticationScheme
            Description                  = $Claim.Description
        }
    }
    $Body = @{
        Id              = $Role.Id
        Name            = $Role.Name
        Description     = if ($Updates.DescriptionUpdate) { $script:Variables.ROLE_DESCRIPTION } else { $Role.Description }
        EmailAddress    = if ($Updates.MailUpdate) { $Member.mail } else { $Role.EmailAddress }
        PermissionSetId = $Role.PermissionSetId
        Permissions     = $Role.Permissions
        Claims          = $Role.Claims
    }
    write-message -Message "Updating Role with body: $($Body | ConvertTo-Json -Depth 10)" -type Verbose
    write-message -Message "Updating Role in Keyfactor Command" -type Debug
    $Url = "$($script:Variables.KeyfactorAPI)/Security/roles"
    $Response = Invoke-WebRequest -Uri $Url -Method Put -Headers (Get-Headers -HeaderVersion 2) -Body ($Body | ConvertTo-Json -Depth 10) -TimeoutSec 30
    if ($Response.StatusCode -ne 200)
    {
        write-message -Message "Error updating role '$($Role.Name)': $($Response.StatusCode) $($Response.StatusDescription)" -type Error
        return $null
    }
    write-message -Message "Leaving function update-role for role '$($Role.Name)'" -type Debug
    return $Response.Content | ConvertFrom-Json
}

try 
{
    $WarningPreference = 'Stop'
    $InformationPreference = 'Continue'

    if ($script:loglevel -eq 'Debug') 
    {
        $DebugPreference = 'Continue'
        $VerbosePreference = 'SilentlyContinue'
    } 
    elseif ($script:loglevel -eq 'Verbose') 
    {
        $VerbosePreference = 'Continue'
        $DebugPreference = 'Continue'
    } 
    else
    {
        $DebugPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'
    }

    if (-not $script:environment) 
    {
        throw "environment is a required parameter. Allowed values are 'Production', 'NonProduction', 'Lab'."
    }

    write-message -Message "Script execution started with parameters environment=$script:environment" -type Info
    write-message -Message "Received parameters: environment=$script:environment" -type Debug
    Write-Message -Message "Cleaning up old log files." -Type Info
    Remove-Logs -LogFolder $script:logfolder -DaysOld $script:retentiondays
    
    $Script:Variables = Get-Variables -environment_variables $script:environment

    if ([string]::IsNullOrEmpty($script:Variables.client_secret))
    {
        $CLIENT_SECRET = Read-Host "Please enter your IDP Applications Client Secret"
        $script:Variables.CLIENT_SECRET = $CLIENT_SECRET
        write-message -Message "Saved Client_Secret in Memory Only" -type Info
    }
    if ($script:Variables.CLIENT_ID)
    {
        write-message -message  "Loaded Variables for $script:environment environment" -type Info
    }
    else
    {
        write-message -message  "Could not load Variables for $script:environment" -type Error
    }

    if (Get-KeyfactorStatus)
    {
        write-message -message  "Validated connection to Keyfactor Command" -type Debug
    }
    else
    {
        write-message -message  "Could not validate connection to Keyfactor Command" -type Error
    }
    $members = Get-EntraGroupTransitiveMembers -GroupName $script:Variables.entra_all_users_group
    $roles = get-roles
    $claims = get-claims
    foreach ($member in $members) 
    {
        write-message -Message "Found group member: DisplayName='$($member.displayName)'" -type Debug
        $membername = $member.displayName
        $role = $roles | Where-Object { $_.Name -eq $membername } | Select-Object -First 1
        $claim = $claims | Where-Object { $_.ClaimValue -eq $membername } | Select-Object -First 1
        if ($claim) 
        {
            write-message -Message "Claim found for member '$membername': ID=$($claim.Id), Name='$($claim.ClaimValue)'" -type Info
        } 
        else 
        {
            write-message -Message "No claim found for member '$membername'" -type Warning
            $claim = new-claim -claimName $membername 
        }
        if ($role) 
        {
            write-message -Message "Role found for member '$membername': ID=$($role.Id), Name='$($role.Name)'" -type Info
            $updates = confirm-role -Role $role -Member $member -Claim $claim
            if ($updates.DescriptionUpdate -or $updates.ClaimUpdate -or $updates.MailUpdate)
            {
                write-message -Message "Role '$($role.Name)' requires updates." -type Warning
                $role = update-role -Role $role -Member $member -Claim $claim -Updates $updates
                write-message -Message "Updated role for member '$membername': ID=$($role.Id), Name='$($role.Name)'" -type Info
            }
            else
            {
                write-message -Message "Role '$($role.Name)' is up to date. No action needed." -type Info
            }
        } 
        else 
        {
            write-message -Message "No role found for member '$membername'" -type Warning
            $role = new-role -roleName $membername -mail $member.mail -claim $claim
            write-message -Message "Created role for member '$membername': ID=$($role.Id), Name='$($role.Name)'" -type Info
        }
    }
}
catch
{
    $_ | out-File -FilePath .\logs.txt -Append
}
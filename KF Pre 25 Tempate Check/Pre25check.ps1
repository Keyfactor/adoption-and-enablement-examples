<#
.SYNOPSIS
    Retrieves and analyzes Keyfactor certificate templates for specific policy and configuration settings.

.DESCRIPTION
    This script authenticates to the Keyfactor API using OAuth2 client credentials, retrieves all certificate templates with AllowedEnrollmentTypes set to 0, and checks each template for specific settings and policy configurations. It outputs a summary of findings for each template.

.PARAMETER KeyfactorAPI
    The base URL of the Keyfactor API. Must start with 'https://'.

.PARAMETER CLIENTID
    The OAuth2 client ID used for authentication.

.PARAMETER IDP_AUDIENCE
    (Optional) The audience parameter for the identity provider token request.

.PARAMETER IDP_SCOPE
    (Optional) The scope parameter for the identity provider token request.

.PARAMETER TOKEN_ENDPOINT
    The OAuth2 token endpoint URL. Must start with 'https://'.

.PARAMETER loglevel
    The log level for script output. Valid values are 'Info', 'Debug', or 'Verbose'. Default is 'Info'.

.PARAMETER SECRET
    The secret associated with the client ID. If not provided, the script will prompt for it securely.

.FUNCTIONS
    Get-AuthToken
        Authenticates with the identity provider and retrieves an access token.

    Get-Templates
        Retrieves all certificate templates from the Keyfactor API.

    Get-TemplateById
        Retrieves detailed information for a specific template by its ID.

    Invoke-CheckTemplate
        Analyzes each template for specific settings and policy configurations, returning a summary per template.

.EXAMPLE
    .\test5.ps1 -KeyfactorAPI "https://keyfactor.example.com/API" -CLIENTID "my-client-id" -TOKEN_ENDPOINT "https://idp.example.com/oauth2/token" -SECRET "my-secret"

.NOTES
    - Requires PowerShell 5.1 or later.
    - Requires network access to the Keyfactor API and the identity provider.
    - Ensure the client ID and secret have appropriate permissions to access the Keyfactor API.

#>

param(
    [Parameter(Mandatory, Position = 0, HelpMessage = "Specify the Keyfactor API URL.")]
    [ValidatePattern('^https://')]
    [string]$KeyfactorAPI,

    [Parameter(Mandatory, Position = 1, HelpMessage = "Specify the Client ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$CLIENTID,

    [Parameter( Position = 2, HelpMessage = "Specify the IDP audience (optional).")]
    [string]$IDP_AUDIENCE = $null,

    [Parameter( Position = 3, HelpMessage = "Specify the IDP scope (optional).")]
    [string]$IDP_SCOPE = $null,

    [Parameter(Mandatory, HelpMessage = "Specify the IDP token endpoint.")]
    [ValidatePattern('^https://')]
    [string]$TOKEN_ENDPOINT,

    [Parameter(HelpMessage = "Specify the log level.")]
    [ValidateSet("Info", "Debug", "Verbose")]
    [string]$loglevel = 'Info',

    [Parameter(Mandatory, HelpMessage = "Specify the secret for the Client ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$SECRET
)


if (-not $SECRET) {
    $SECRET = Read-Host -AsSecureString -Prompt "Enter the secret for the Client ID" | ConvertFrom-SecureString -AsPlainText -Force
}

#define headers
$HEADERS = @{
    "Content-Type" = "application/json"
    "x-keyfactor-requested-with" = "APIClient"
}

function Get-AuthToken {
    $headers = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    $body = @{
        'grant_type'    = 'client_credentials'
        'client_id'     = $CLIENTID
        'client_secret' = $SECRET
    }

    if ($IDP_AUDIENCE) {
        $body['audience'] = $IDP_AUDIENCE
    }
    if ($IDP_SCOPE) {
        $body['scope'] = $IDP_SCOPE
    }

    try {
        $response = Invoke-RestMethod -Uri $TOKEN_ENDPOINT -Method Post -Headers $headers -Body $body
        return $response.access_token
    } catch {
        Write-Error "Error getting token: $_"
        return $null
    }
}

function Get-Templates {
    param($token)
    $headers = $HEADERS.Clone()
    $headers["Authorization"] = "Bearer $token"
    $headers["x-keyfactor-api-version"] = "1.0"

    try {
        $url = "$KeyfactorAPI/Templates?ReturnLimit=5000"
        return Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    } catch {
        Write-Error "Error getting templates: $_"
        return $null
    }
}

function Get-TemplateById {
    param($token, $id)
    $headers = $HEADERS.Clone()
    $headers["Authorization"] = "Bearer $token"
    $headers["x-keyfactor-api-version"] = "1.0"

    try {
        return Invoke-RestMethod -Uri "$KeyfactorAPI/Templates/$id" -Headers $headers -Method Get
    } catch {
        Write-Error "Error getting template by ID: $_"
        return $null
    }
}

function Invoke-CheckTemplate {
    param($templates)
    $results = @{}

    foreach ($template in $templates) {
        $policy = $template.TemplatePolicy | ConvertTo-Json -Depth 10
        $policy = $policy | ConvertFrom-Json
        $commonName = $template.CommonName
        if (-not $commonName) { $commonName = "UnknownCommonName" }
        if (-not $results.ContainsKey($commonName)) { $results[$commonName] = @() }
        if ($template.UseAllowedRequesters) { $results[$commonName] += 'UseAllowedRequesters' }
        if ($template.EnrollmentFields.count -gt 0) { $results[$commonName] += 'EnrollmentFields' }
        if ($template.TemplateRegexes.count -gt 0) { $results[$commonName] += 'TemplateRegexes' }
        if ($template.TemplateDefaults.count -gt 0) { $results[$commonName] += 'TemplateDefaults' }
        if ($policy.RFCEnforcement) { $results[$commonName] += 'TemplatePolicy.RFCEnforcement' }
        if ($null -ne $policy.AllowKeyReuse) { $results[$commonName] += 'TemplatePolicy.AllowKeyReuse' }
        if ($null -ne $policy.AllowWildcards) { $results[$commonName] += 'TemplatePolicy.AllowWildcards' }
        if ($null -ne $policy.CertificateOwnerRole) { $results[$commonName] += 'TemplatePolicy.CertificateOwnerRole' }
        if ($null -ne $policy.DefaultCertificateOwnerRoleId) { $results[$commonName] += 'TemplatePolicy.DefaultCertificateOwnerRoleId' }
        if ($null -ne $policy.DefaultCertificateOwnerRoleName) { $results[$commonName] += 'TemplatePolicy.DefaultCertificateOwnerRoleName' }
        if ($results[$commonName].count -eq 0) {
            $results[$commonName] = 'No issues found'
        } else {
            $results[$commonName] = $results[$commonName] -join ', '
        }
    }
    return $results
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

    Write-Information "Starting script"
    Write-Information "Getting token"
    $token = Get-AuthToken
    if ($null -eq $token) {
        Write-Error "Failed to get token"
        exit
    }
    Write-Information "Token obtained successfully"
    Write-Information "Getting templates"
    $templates = Get-Templates -token $token
    if ($null -eq $templates) {
        Write-Error "Failed to get templates"
        exit
    }
    Write-Information "Templates obtained successfully"
    $templates = $templates | Where-Object { $_.AllowedEnrollmentTypes -eq 0 }
    if ($null -eq $templates) {
        Write-Error "No templates found"
        exit
    }
    $alltemplateDetails = @()
    $templates | ForEach-Object {
        Write-Information "Processing template: $($_.CommonName)"
        $templateDetails = Get-TemplateById -token $token -id $_.Id
        if ($null -eq $templateDetails) {
            Write-Error "Failed to get template details for ID: $($_.CommonName)"
            continue
        }
        $alltemplateDetails += $templateDetails
    }
    $alltemplateDetails = $alltemplateDetails | Where-Object { $_.AllowedEnrollmentTypes -eq 0 }

    $results = Invoke-CheckTemplate -templates $alltemplateDetails
    if ($null -eq $results) {
        Write-Error "Failed to check templates"
        exit
    }
    write-host "Templates and setting to check: $($results | ConvertTo-Json -Depth 10)"
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    Write-Information "Script execution completed"
}
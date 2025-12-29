<#
.SYNOPSIS
    ACME Claims Management Script - Manages user claims, roles, and templates in Keyfactor ACME service.

.DESCRIPTION
    This script provides a menu-driven interface to manage ACME claims across multiple environments (Production, Non-Production, Lab).
    It supports CRUD operations on claims, role assignment, and template management through OAuth 2.0 authentication.

.FUNCTIONS

    Get-AcmeEnvironment
        Retrieves environment-specific configuration (CLIENT_ID, CLIENT_SECRET, TOKEN_URL, SCOPE, AUDIENCE, ACMEDNS).
        Parameters: $EnvironmentName (Prod, NonProd, lab)
        Returns: Hashtable with environment variables

    Get-AcmeHeaders
        Generates OAuth 2.0 bearer token and returns authorization headers.
        Parameters: $Vars (environment variables)
        Returns: Hashtable with Authorization and Accept headers

    Invoke-AcmeRequest
        Sends HTTP requests to ACME API with automatic authentication.
        Parameters: $Uri, $Method, $Body, $Vars
        Returns: Web response object

    Test-AcmeConnection
        Validates connectivity to ACME service endpoint.
        Parameters: $Vars
        Returns: Boolean

    Get-AcmeClaims
        Retrieves all claims or a specific claim by ID.
        Parameters: $Vars, $Id (optional)
        Returns: PSObject with claim data

    Add-AcmeClaim
        Creates a new claim with specified ClaimValue, Roles, and optional Template.
        Parameters: $Vars, $ClaimValue, $Roles, $Template

    Update-AcmeClaim
        Updates an existing claim's roles and/or templates.
        Parameters: $Vars, $Claim, $Template, $Role, $Remove (switch)

    Remove-AcmeClaim
        Deletes a claim by ID.
        Parameters: $Vars, $Id
        Returns: Boolean

    Show-Claims
        Displays all claims in formatted table.
        Parameters: $Vars

    Remove-AcmeClaimMenu
        Interactive menu for deleting claims with confirmation.
        Parameters: $Vars

    Add-AcmeClaimMenu
        Interactive menu for creating new claims with role selection.
        Parameters: $Vars

    Update-AcmeClaimMenu
        Interactive menu for modifying existing claims.
        Parameters: $Vars

    Invoke-ActionMenu
        Main action selection menu (Show/Add/Update/Remove Claims).
        Parameters: $Vars

    Invoke-MainMenu
        Environment selection menu (Production, Non-Production, Lab).
        Returns: Selected environment variables

.NOTES
    Author: Keyfactor TAM Team
    Version: 1.0
    Requirements: PowerShell 5.0+, network connectivity to ACME service
    Configuration: Update CLIENT_ID, CLIENT_SECRET, TOKEN_URL, SCOPE, AUDIENCE in Get-AcmeEnvironment for each environment
    Role Types: AccountAdmin, EnrollmentUser, SuperAdmin
#>
function Get-AcmeEnvironment {
    param($EnvironmentName)
    $config = @{
        'Production' = @{
            CLIENT_ID     = ''
            CLIENT_SECRET = ''
            TOKEN_URL     = ''
            SCOPE         = ''
            AUDIENCE      = ''
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
        'Non-Production' = @{
            CLIENT_ID     = ''
            CLIENT_SECRET = ''
            TOKEN_URL     = ''
            SCOPE         = ''
            AUDIENCE      = ''
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
        'lab' = @{
            CLIENT_ID     = ''
            CLIENT_SECRET = ''
            TOKEN_URL     = ''
            SCOPE         = ''
            AUDIENCE      = ''
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
    }
    $vars = $config[$EnvironmentName]
    Write-Host "Loaded variables for $EnvironmentName environment."
    return $vars
}
function Get-AcmeHeaders {
    param($Vars)
    $authBody = @{
        grant_type    = 'client_credentials'
        client_id     = $Vars.CLIENT_ID
        client_secret = $Vars.CLIENT_SECRET
        scope         = $Vars.SCOPE
        audience      = $Vars.AUDIENCE
    }
    try {
        $response = Invoke-RestMethod -Method Post -Uri $Vars.TOKEN_URL -Body $authBody -Headers @{'Content-Type' = 'application/x-www-form-urlencoded'}
        return @{ Authorization = "Bearer $($response.access_token)"; Accept = "application/json" }
    } catch {
        throw "Failed to fetch OAuth token: $_"
    }
}
function Invoke-AcmeRequest {
    param($Uri, $Method = 'Get', $Body = $null, $Vars)
    $params = @{
        Uri               = $Uri
        Method            = $Method
        Headers           = Get-AcmeHeaders -Vars $Vars
        ContentType       = "application/json"
        UseBasicParsing   = $true
        ErrorAction       = 'Stop'
    }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json) }
    return Invoke-WebRequest @params
}
function Test-AcmeConnection {
    param($Vars)
    try {
        $response = Invoke-AcmeRequest -Uri "$($Vars.ACMEDNS)/status" -Vars $Vars
        return $response.StatusCode -eq 204
    } catch { return $false }
}
function Get-AcmeClaims {
    param($Vars, $Id = $null)
    $uri = "$($Vars.ACMEDNS)/Claims$(if ($Id) { "/$Id" })"
    $response = Invoke-AcmeRequest -Uri $uri -Vars $Vars
    return $response.Content | ConvertFrom-Json
}
function Add-AcmeClaim {
    param($Vars, $ClaimValue, $Roles, $Template = $null)
    $body = @{ ClaimType = 'Sub'; ClaimValue = $ClaimValue; Roles = ($Roles -split ' ') }
    if ($Template) { $body.Template = $Template }
    $response = Invoke-AcmeRequest -Uri "$($Vars.ACMEDNS)/Claims" -Method Post -Body $body -Vars $Vars
    if ($response.StatusCode -eq 200) { Write-Information "Claim $ClaimValue added successfully.";Show-Claims -Vars $Vars; pause }
}
function Update-AcmeClaim {
    param($Vars, $Claim, $Template, $Role, [switch]$Remove)
    $body = @{
        ClaimType  = $Claim.ClaimType
        ClaimValue = $Claim.ClaimValue
        Roles      = @(if ($Role) {$Role -split '\s+'} else {$Claim.Roles})
        Template   = $Claim.Template
    }
    if ($Template) {
        $templates = if ($Remove) { @($Template) } else { @($Template) + @($Claim.template) | Where-Object { $_ } }
        $body.Template = ($templates | Select-Object -Unique) -join ' '
    }
    $response = Invoke-AcmeRequest -Uri "$($Vars.ACMEDNS)/Claims/$($Claim.id)" -Method Put -Body $body -Vars $Vars
    if ($response.StatusCode -eq 200) { Write-Information "Claim updated successfully.";Show-Claims -Vars $Vars; pause }
}
function Remove-AcmeClaim {
    param($Vars, $Id)
    $response = Invoke-AcmeRequest -Uri "$($Vars.ACMEDNS)/Claims/$Id" -Method Delete -Vars $Vars
    return $response.StatusCode -eq 204
}
function Show-Claims {
    param($Vars)
    $claims = Get-AcmeClaims -Vars $Vars
    if ($claims) { return $claims | Format-Table -AutoSize | Out-Host } else { Write-Host "No claims found." -ForegroundColor Yellow }
}
function Remove-AcmeClaimMenu {
    param($Vars)
    while ($true) {
        $claims = Get-AcmeClaims -Vars $Vars
        if (-not $claims) { Write-Host "No claims available."; return }
        $claims | Format-Table -AutoSize | Out-Host
        $id = Read-Host "Enter Claim ID to remove (or Enter to return)"
        if ([string]::IsNullOrWhiteSpace($id)) { return }
        elseif (-not ($claims | Where-Object { $_.id -eq $id })) {
            Write-Host "Id: $id is not a valid claim Id. Returning to Remove Menu." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
            continue
        }
        $superadmincount = ($claims | Where-Object { $_.Roles -contains 'SuperAdmin' }).count
        if (($claims | Where-Object { $_.id -eq $id }).Roles -contains 'SuperAdmin' -and $superadmincount -le 1) {
            Write-Host "Cannot remove the last SuperAdmin claim." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }
        if (Remove-AcmeClaim -Vars $Vars -Id $id) { Write-Host "Removed ID $id." -ForegroundColor Green }
        Start-Sleep -Seconds 1
    }
}
function Add-AcmeClaimMenu {
    param($Vars)
    $roleMap = @{ '1' = 'EnrollmentUser'; '2' = 'AccountAdmin'; '3' = 'SuperAdmin' }
    while ($true) {
        Write-Host "=== Add Claim ===`n[1] EnrollmentUser`n[2] AccountAdmin`n[3] SuperAdmin`n[4] Return"
        $response = Read-Host "Select roles (e.g. 1,2)"
        if ($response -eq '4' -or [string]::IsNullOrWhiteSpace($response)) { return }
        $selectedRoles = ($response -split '[,\s]+' | ForEach-Object { $roleMap[$_] } | Where-Object { $_ })
        $claimValue = Read-Host "Enter Claim Subject"
        $template = if ($selectedRoles -contains 'EnrollmentUser') { Read-Host "Template Shortname required" } else { $null }
        Add-AcmeClaim -Vars $Vars -ClaimValue $claimValue -Roles ($selectedRoles -join ' ') -Template $template
        if ((Read-Host "Add another? (y/n)") -ne 'y') { return $true }
    }
}
function Update-AcmeClaimMenu {
    param($Vars)
    while ($true) {
        $claims = Get-AcmeClaims -Vars $Vars
        $claims | Format-Table -AutoSize | Out-Host
        $id = Read-Host "Enter Claim ID or press enter to return to the action menu"
        if (-not $id) { write-host "no entry selected, returning to action menu"; start-sleep -seconds 1.5; return}
        $claim = $claims | Where-Object { $_.id -eq $id }
        if (-not $claim.id) { write-host "Id: $id is not a valid claim Id. Returning to Action Menu."; start-sleep -seconds 1.5; return}
        Write-Host "=== Update Claim ===`n[1] Add Template`n[2] New Template (Clear others)`n[3] Update Roles`n[4] Return"
        $action = Read-Host "Choose an action to complete or press enter to return to the action menu"
        if ($action -eq '4') { return }
        elseif (-not $action) { return}
        switch ($action) {
            '1' { Update-AcmeClaim -Vars $Vars -Claim $claim -Template (Read-Host "Template Shortname") }
            '2' { Update-AcmeClaim -Vars $Vars -Claim $claim -Template (Read-Host "Template Shortname") -Remove }
            '3' { 
                $roleMap = @{ '1' = 'EnrollmentUser'; '2' = 'AccountAdmin'; '3' = 'SuperAdmin' }
                write-host "[1] EnrollmentUser`n[2] AccountAdmin`n[3] SuperAdmin`n[4] Return"
                $roles = Read-Host "Enter new roles (space separated)"
                if ($roles -eq '4' -or [string]::IsNullOrWhiteSpace($roles)) { return }
                $selectedRoles = ($roles -split '[,\s]+' | Where-Object { $_ -and $roleMap.ContainsKey($_) } | ForEach-Object { $roleMap[$_] })
                Update-AcmeClaim -Vars $Vars -Claim $claim -Role $selectedRoles
            }
            default { write-host "no entry selected, returning to action menu"; start-sleep -seconds 1.5; return}
        }
    }
}
function Invoke-ActionMenu {
    param($Vars)
    while ($true) {
        Write-Host "=== Action Menu ===`n[1] Show Claims`n[2] Add Claim`n[3] Update Claim`n[4] Remove Claim`n[5] Exit"
        switch (Read-Host "Select Action") {
            '1' { Show-Claims -Vars $Vars; pause }
            '2' { Add-AcmeClaimMenu -Vars $Vars }
            '3' { Update-AcmeClaimMenu -Vars $Vars }
            '4' { Remove-AcmeClaimMenu -Vars $Vars }
            '5' { return }
        }
    }
}
function Invoke-MainMenu {
    while ($true) {
        Write-Host "=== Environment Menu ===`n[1] Production`n[2] Non-Production`n[3] Lab`n[4] Exit"
        $choice = Read-Host "Choice"
        if ($choice -eq '4') { return $null }
        $env = switch($choice) { '1' {'Production'} '2' {'Non-Production'} '3' {'Lab'} }
        if ($env) { return Get-AcmeEnvironment -EnvironmentName $env }
    }
}

# Main Script
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
try {
    $Variables = Invoke-MainMenu
    if ($Variables -and (Test-AcmeConnection -Vars $Variables)) {
        Invoke-ActionMenu -Vars $Variables
    } elseif ($Variables) {
        Write-Error "Acme Service unreachable."
    }
} catch {
    Write-Error "Fatal: $_"
}
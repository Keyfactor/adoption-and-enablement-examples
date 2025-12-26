function Get-AcmeEnvironment {
    param($EnvironmentName)
    $config = @{
        'Prod' = @{
            CLIENT_ID     = ''
            CLIENT_SECRET = ''
            TOKEN_URL     = ''
            SCOPE         = ''
            AUDIENCE      = ''
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
        'NonProd' = @{
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
        Clear-Host
        $claims = Get-AcmeClaims -Vars $Vars
        if (-not $claims) { Write-Host "No claims available."; return }
        $claims | Format-Table -AutoSize | Out-Host
        $id = Read-Host "Enter Claim ID to remove (or Enter to return)"
        if ([string]::IsNullOrWhiteSpace($id)) { return }
        if (Remove-AcmeClaim -Vars $Vars -Id $id) { Write-Host "Removed ID $id." -ForegroundColor Green }
        Start-Sleep -Seconds 1
    }
}
function Add-AcmeClaimMenu {
    param($Vars)
    $roleMap = @{ '1' = 'AccountAdmin'; '2' = 'EnrollmentUser'; '3' = 'SuperAdmin' }
    while ($true) {
        Clear-Host
        Write-Host "=== Add Claim ===`n[1] AccountAdmin`n[2] EnrollmentUser`n[3] SuperAdmin`n[4] Return"
        $response = Read-Host "Select roles (e.g. 1,2)"
        if ($response -eq '4' -or [string]::IsNullOrWhiteSpace($response)) { return }
        $selectedRoles = ($response -split '[,\s]+' | ForEach-Object { $roleMap[$_] } | Where-Object { $_ })
        $claimValue = Read-Host "Enter Claim Subject"
        $template = if ($selectedRoles -contains 'EnrollmentUser') { Read-Host "Template name required" } else { $null }
        Add-AcmeClaim -Vars $Vars -ClaimValue $claimValue -Roles ($selectedRoles -join ' ') -Template $template
        if ((Read-Host "Add another? (y/n)") -ne 'y') { return $true }
    }
}
function Update-AcmeClaimMenu {
    param($Vars)
    while ($true) {
        Clear-Host
        Write-Host "=== Update Claim ===`n[1] Add Template`n[2] New Template (Clear others)`n[3] Update Roles`n[4] Return"
        $action = Read-Host "Choose an action to complete or press enter to return to the action menu"
        if ($action -eq '4') { return }
        elseif (-not $action) { return}
        $claims = Get-AcmeClaims -Vars $Vars
        $claims | Format-Table -AutoSize | Out-Host
        $id = Read-Host "Enter Claim ID or press enter to return to the action menu"
        if (-not $id) { write-host "no entry selected, returning to action menu"; start-sleep -seconds 1.5; return}
        $claim = $claims | Where-Object { $_.id -eq $id }
        if (-not $claim.id) { write-host "Id: $id is not a valid claim Id. Returning to Action Menu."; start-sleep -seconds 1.5; return}
        switch ($action) {
            '1' { Update-AcmeClaim -Vars $Vars -Claim $claim -Template (Read-Host "Template") }
            '2' { Update-AcmeClaim -Vars $Vars -Claim $claim -Template (Read-Host "Template") -Remove }
            '3' { 
                $roleMap = @{ '1' = 'AccountAdmin'; '2' = 'EnrollmentUser'; '3' = 'SuperAdmin' }
                write-host "[1] AccountAdmin`n[2] EnrollmentUser`n[3] SuperAdmin`n[4] Return"
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
        Clear-Host
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
        Clear-Host
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
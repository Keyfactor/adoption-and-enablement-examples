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
        'Lab' = @{
            CLIENT_ID     = 'd424706f-3c5f-453e-8b6e-2be54788bd17'
            CLIENT_SECRET = 'Z5ETEC_mY8Z6McI8t2KRz5h-eXeQYm~1y0xngF06VlF8.ttCtDX1vAAjAO_U6ghm'
            TOKEN_URL     = 'https://auth.pingone.com/3729a543-20bf-44b1-b92b-7ceef13aeecf/as/token'
            SCOPE         = 'APISCOPE'
            AUDIENCE      = 'APISCOPE'
            ACMEDNS       = 'https://boeingoauth.kfdelivery.com/ACME'
        }
    }
    $vars = $config[$EnvironmentName]
    if ($null -eq $vars) {
        return $false
    }
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
    $response = Invoke-RestMethod -Method Post -Uri $Vars.TOKEN_URL -Body $authBody -Headers @{'Content-Type' = 'application/x-www-form-urlencoded'}
    if (-not $response.access_token) {
        return $false
    }
    return @{ Authorization = "Bearer $($response.access_token)"; Accept = "application/json" }
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
    if ($response.StatusCode -eq 200) { Write-Information "Claim $ClaimValue added successfully." -foregroundcolor Green }
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
    if ($response.StatusCode -eq 200) { Write-Information "Claim updated successfully."}
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
        $id = Read-Host "Enter Claim ID to remove (or Enter to return to the action menu)"
        if ([string]::IsNullOrWhiteSpace($id)) { return }
        elseif (-not ($claims | Where-Object { $_.id -eq $id })) {
            Write-Host "Id: $id is not a valid claim Id. please select a valid claim Id." -ForegroundColor Red
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
        Write-Host "=== Add Claim ===`n[1] EnrollmentUser`n[2] AccountAdmin`n[3] SuperAdmin`n[4] Return to action menu"
        $response = Read-Host "Select roles (e.g. 1,2)"
        if ($response -eq '4' -or [string]::IsNullOrWhiteSpace($response)) { return }
        if ($response -notin '1','2','3') {
            Write-Host "Invalid selection, please select again." -ForegroundColor Red
            continue
        }
        $selectedRoles = ($response -split '[,\s]+' | ForEach-Object { $roleMap[$_] } | Where-Object { $_ })
        $claimValue = Read-Host "Enter Claim Subject"
        $template = if ($selectedRoles -contains 'EnrollmentUser') { Read-Host "Template Shortname required" } else { $null }
        Add-AcmeClaim -Vars $Vars -ClaimValue $claimValue -Roles ($selectedRoles -join ' ') -Template $template
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
        if (-not $claim.id) { write-host "Id: $id is not a valid claim Id. Please select a valid claim Id."; continue}
        while ($true) {
            Write-Host "=== Update Claim ===`n[1] Add Template`n[2] New Template (Clear others)`n[3] Update Roles`n[4] Return to Action Menu"
            $action = Read-Host "Choose an action to complete or press enter to return to the action menu"
            if ($action -eq '4') { return }
            elseif (-not $action) { return}
            if ($action -notin '1','2','3','4') {
                Write-Host "Invalid action, please try again." -ForegroundColor Red
                continue
            }
        }
        switch ($action) {
            '1' { Update-AcmeClaim -Vars $Vars -Claim $claim -Template (Read-Host "Template Shortname") }
            '2' { Update-AcmeClaim -Vars $Vars -Claim $claim -Template (Read-Host "Template Shortname") -Remove }
            '3' { 
                $roleMap = @{ '1' = 'EnrollmentUser'; '2' = 'AccountAdmin'; '3' = 'SuperAdmin' }
                write-host "[1] EnrollmentUser`n[2] AccountAdmin`n[3] SuperAdmin`n[4] Return"
                $roles = Read-Host "Enter new roles (space separated)"
                if ($roles -eq '4' -or [string]::IsNullOrWhiteSpace($roles)) { return }
                if ($action -notin '1','2','3') {
                    Write-Host "Invalid action, please try again." -ForegroundColor Red
                    continue
                }
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
        $action = Read-Host "Select an Action"
        if ($action -notin '1','2','3','4','5') {
            Write-Host "Invalid action, please select again." -ForegroundColor Red
            continue
        }
        switch ($action) {
            '1' { Show-Claims -Vars $Vars}
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
        if ($choice -notin '1','2','3') {
            Write-Host "Invalid choice, please select again." -ForegroundColor Red
            continue
        }
        $env = switch($choice) { '1' {'Production'} '2' {'Non-Production'} '3' {'Lab'} }
        if ($env) { return Get-AcmeEnvironment -EnvironmentName $env }
    }
}

# Main Script
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
try {
    $Variables = Invoke-MainMenu
    if (-not $Variables) { Write-Host "unable to load environment variables.Exiting script."; exit }
    if (-not (Get-AcmeHeaders -Vars $Variables)) { Write-Host "Unable to retrieve OAuth token, Please check variables."; exit }
    if (-not (Test-AcmeConnection -Vars $Variables)) {Write-host "Unable to connect to Acme Service, Please check variables."; exit}
    Invoke-ActionMenu -Vars $Variables
} catch {
    write-error "An error occurred: $_"
}
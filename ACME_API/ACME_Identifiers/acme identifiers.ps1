<#
.SYNOPSIS
    Manages ACME DNS identifiers across different environments.

.DESCRIPTION
    This script provides functionality to add, remove, and show ACME DNS identifiers.
    It supports multiple environments (Production, Non-Production, Lab) and handles OAuth authentication.

.PARAMETER environment
    The target environment to operate in.
    Valid values: "Production", "Non-Production", "Lab"

.PARAMETER action
    The action to perform on identifiers.
    Valid values: "add", "remove", "show"

.PARAMETER Identifier
    Dynamic parameter that appears when action is "add".
    The identifier string to be added.

.PARAMETER Type
    Dynamic parameter that appears when action is "add".
    The type of identifier to add.
    Valid values: "Regex", "Fqdn", "Subnet", "Wildcard"

.EXAMPLE
    .\script.ps1 -environment Production -action show
    Lists all identifiers in the Production environment.

.EXAMPLE
    .\script.ps1 -environment Lab -action add -Identifier "example.com" -Type Fqdn
    Adds a new FQDN identifier "example.com" in the Lab environment.

.EXAMPLE
    .\script.ps1 -environment Non-Production -action remove
    Shows all identifiers and prompts for an ID to remove from Non-Production environment.

.NOTES
    Author: Keyfactor Technical Account Management Team
    Version: 1.0
    Last Modified: 8\21\2025
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Production", "Non-Production", "Lab")]
    [ValidateNotNullOrEmpty()]
    [string]$environment,
    [Parameter(Mandatory = $true)]
    [ValidateSet("add", "remove", "show")]
    [ValidateNotNullOrEmpty()]
    [string]$action
)
DynamicParam {
    $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    if ($action -eq "add") {
        $attributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $attributes.Add((New-Object System.Management.Automation.ParameterAttribute -Property @{ Mandatory = $true }))
        $paramDictionary.Add("Identifier", (New-Object System.Management.Automation.RuntimeDefinedParameter("Identifier", [string], $attributes)))

        $attributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $validateSet = New-Object System.Management.Automation.ValidateSetAttribute("Regex", "Fqdn", "Subnet", "Wildcard")
        $attributes.Add($validateSet)
        $attributes.Add((New-Object System.Management.Automation.ParameterAttribute -Property @{ Mandatory = $true }))
        $paramDictionary.Add("Type", (New-Object System.Management.Automation.RuntimeDefinedParameter("Type", [string], $attributes)))
    }

    return $paramDictionary
}
begin {
    # Access dynamic parameters if needed
    if ($action -eq "add") {
        $Type = $PSBoundParameters["Type"]
        $Identifier = $PSBoundParameters["Identifier"]
    }
}
Process
{
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
                    CLIENT_SECRET   = ''
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
                    CLIENT_SECRET   = ''
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
                    CLIENT_SECRET   = ''
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
    function Add-Identifier
    {
        try 
        {
            $body = @{
                "Identifier" = $Identifier
                "Type"       = $Type
            }
            $postcall = Invoke-WebRequest -Uri "$($Variables.ACMEDNS)/Identifiers" -Method Post -Headers (Get-ACMEHeaders) -ContentType "application/json" -Body ($body | ConvertTo-Json)
            if ($postcall.StatusCode -eq 200)
            {
                Write-Information "Identifier: $Identifier was added successfully."
            }
            else {
                Write-Error -Message "Failed to add identifier: $($_.Exception.Message)"
            }
        } 
        catch 
        {
            Write-Error "An error occurred: $_"
        }
    }
    function Show-Identifiers
    {
        try 
        {
            $getcall = Invoke-WebRequest -Uri "$($Variables.ACMEDNS)/Identifiers" -Method Get -Headers (Get-ACMEHeaders) -ContentType "application/json"
            if ($getcall.StatusCode -eq 200)
            {
                return $getcall.Content | ConvertFrom-Json
            }
            else {
                Write-Error -Message "Failed to get identifiers: $($_.Exception.Message)"
            }
        } 
        catch 
        {
            Write-Error "An error occurred in get-Identifiers: $($_.Exception.Message)"
        }
    }
    function Remove-Identifier
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Id
        )
        try 
        {
            $deletecall = Invoke-WebRequest -Uri "$($Variables.ACMEDNS)/Identifiers/$id" -Method Delete -Headers (Get-ACMEHeaders) -ContentType "application/json"
            if ($deletecall.StatusCode -eq 204)
            {
                Write-Host "Identifier: $Identifier was removed successfully."
            }
            else {
                Write-Error -Message "Failed to remove identifier: $($_.Exception.Message)"
            }
        } 
        catch 
        {
            Write-Error "An error occurred in remove-Identifier: $($_.Exception.Message)"
        }
    }
    $InformationPreference = "Continue"
    $ErrorActionPreference = "Stop"

    # Test the Get-Headers function by calling it
    try 
    {
        $Variables = load_variables -environment $environment
        if ([string]::IsNullOrEmpty($Variables['client_secret'])) {
            $Variables['client_secret'] = Read-Host "Please enter the client secret for the $environment environment"
        }
        if ($action -eq "add")
        {
            Add-Identifier
        }
        elseif ($action -eq "show")
        {
            Show-Identifiers | Format-Table -AutoSize
        }
        elseif ($action -eq "remove")
        {
            Show-Identifiers | Format-Table -AutoSize
            $Id = Read-Host "Enter the ID of the identifier to remove"
            Remove-Identifier -Id $Id
        }
        else 
        {
            Write-Error "Invalid action specified. Use 'add', 'remove', or 'show'."
        }
    } 
    catch 
    {
        Write-Error "An error occurred: $_"
    }
}
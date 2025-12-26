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
    Author: ACME Administration Team
    Version: 1.0
    Requirements: PowerShell 5.0+, network connectivity to ACME service
    Configuration: Update CLIENT_ID, CLIENT_SECRET, TOKEN_URL, SCOPE, AUDIENCE in Get-AcmeEnvironment for each environment
    Role Types: AccountAdmin, EnrollmentUser, SuperAdmin
#>
function Get-AcmeEnvironment {
    param($EnvironmentName)
    $config = @{
        'Prod' = @{
            CLIENT_ID     = 'your_prod_client_id'
            CLIENT_SECRET = 'your_prod_client_secret'
            TOKEN_URL     = 'https://your_prod_token_endpoint'
            SCOPE         = 'your_prod_scope'
            AUDIENCE      = 'your_prod_audience'
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
        'NonProd' = @{
            CLIENT_ID     = 'your_nonprod_client_id'
            CLIENT_SECRET = 'your_nonprod_client_secret'
            TOKEN_URL     = 'https://your_nonprod_token_endpoint'
            SCOPE         = 'your_nonprod_scope'
            AUDIENCE      = 'your_nonprod_audience'
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
        'lab' = @{
            CLIENT_ID     = 'your_lab_client_id'
            CLIENT_SECRET = 'your_lab_client_secret'
            TOKEN_URL     = 'https://your_lab_token_endpoint'
            SCOPE         = 'your_lab_scope'
            AUDIENCE      = 'your_lab_audience'
            ACMEDNS       = 'https://Customer.kfdelivery.com/ACME'
        }
    }
    $vars = $config[$EnvironmentName]
    Write-Host "Loaded variables for $EnvironmentName environment."
    return $vars
}
# ... rest of the functions remain unchanged ...

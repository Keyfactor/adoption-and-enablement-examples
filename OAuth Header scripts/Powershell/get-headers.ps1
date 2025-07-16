# Define script-level variables for the script
$Script:Variables = @{
    # Authentication method (basic or oauth)
    Auth_Method           = "basic"

    # Keyfactor's user credentials if Auth_Method is set to Basic
    keyfactorUser         = "username"
    keyfactorPassword     = "password"
    
    # OAuth-specific parameters if Auth_Method is set to oauth
    client_id             = "<Clientid>"
    client_secret         = "Z<Secret>"
    token_url             = "<TokenURL>"
    scope                 = "<Scope>"
    audience              = "<Audience>"
    GlobalHeaders         = @{
        "Content-Type"              = "application/json"
        "x-keyfactor-requested-with" = "APIClient"
    }
}

function Get-Headers {
    param (
        [string]$APIVersion = "1" # Defaults to "1"
    )

    # Check if Authentication Method is OAuth
    if ($Variables.Auth_Method -eq "oauth") 
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
            Write-Information "Access Token received successfully."
            
            # Add token to headers
            $headers = $Variables.GlobalHeaders.Clone()
            $headers["Authorization"] = "Bearer $token"
            $headers["x-keyfactor-api-version"] = $APIVersion
        } 
        catch 
        {
            Write-Error -Message "Failed to fetch OAuth token: $($_.Exception.Message)"
            throw
        }
        return $headers
    }
    # Check if Authentication Method is Basic
    elseif ($Variables.Auth_Method -eq "basic") 
    {
        Write-Information "Using Basic authentication..."

        try 
        {
            # Create base64 encoded credentials
            $user_pass = "$($Variables.keyfactorUser):$($Variables.keyfactorPassword)"
            $authInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($user_pass))

            # Add the authorization information to headers
            $headers = $Variables.GlobalHeaders.Clone()
            $headers["Authorization"] = "Basic $authInfo"
            $headers["x-keyfactor-api-version"] = $APIVersion
        } 
        catch 
        {
            Write-Error "Failed to create Basic auth headers: $_"
            throw $_
        }
        return $headers
    }
    else 
    {
        throw "Unsupported Auth_Method: $($Variables.Auth_Method)"
    }
}
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

# Test the Get-Headers function by calling it
try 
{
    $result = Get-Headers -APIVersion "2"
    Write-Information "Headers:"
    $result
} 
catch 
{
    Write-Error "An error occurred: $_"
}
try
{
    # Define script level variables for the script using a hashtable
    $script:Variables = @{
        # Authentication method (Basic or OAuth)
        Auth_Method         = "basic"
        # Keyfactor's user credentials if Auth varable is set to Basic
        keyfactorUser       = "username"
        keyfactorPassword   = "password"

        # OAuth-specific parameters if Auth variable is set to oauth
        client_id           = ''
        client_secret       = ''
        token_url           = ""
        scope               = ''
        audience            = ""
        GlobalHeaders = @{
            "Content-Type" = "application/json"
            "x-keyfactor-requested-with" = "APIClient"
        }
    }
}
catch
{
    # If the variables could not be loaded, display a warning and stop the script
    Write-Warning -Message "Could not load variables" -WarningAction Stop
}

function Get-Headers 
{
    [CmdletBinding()]
    param (
        [ValidateSet('1', '2')]
        [Parameter(Mandatory = $false)]
        [string]$APIVersion = '1'
    )
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

        try {
            $token = (Invoke-RestMethod -Method Post -Uri $Variables.token_url -Headers $authHeaders -Body $authBody).access_token
            Write-Information -MessageData "Access Token received successfully." -InformationAction Continue
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
    elseif ($Variables.Auth_Method -eq "basic") 
    {
        $authInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Variables.keyfactorUser):$($Variables.keyfactorPassword)"))
        $headers = $Variables.GlobalHeaders.Clone()
        $headers["Authorization"] = "Basic $authInfo"
        $headers["x-keyfactor-api-version"] = $APIVersion
        return $headers
    }
}

Get-Headers -APIVersion 2
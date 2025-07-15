# Main Block
try
{
    # Define script level variables for the script using a hashtable
    $script:Variables = @{
        # API hostname for Keyfactor
        KEYFACTOR_DNS  = "customerurl.keryfactorpki.com"

        # name that will be seen in Keyfactor Command
        Orchestratorname    = "somename"

        #Autoapprove the agent in Keyfactor Command
        AutoApprove         = $true

        #if trubleshooting you can run in debug mode bt changing the Debug variable to $true
        Debug               = $false

        # Directory where installation scripts are located
        install_directory   = "<installfiles>/InstallationScripts"

        # Boolean to determine if a service account is being used
        use_service_account = $false

        # Authentication method (Basic or OAuth)
        Auth_Method         = "oauth"
        
        # Update Current Orchestrator
        InPlace             = $true

        # Service account credentials if service_account variable is set to $true
        serviceUser         = "username"
        servicePassword     = "password"

        # Keyfactor's user credentials if Auth varable is set to Basic
        keyfactorUser       = "username"
        keyfactorPassword   = "password"

        # OAuth-specific parameters if Auth variable is set to oauth
        client_id           = 'clientid'
        client_secret       = 'secret'
        token_url           = "tokenurl"
        scope               = 'scope'
        audience            = "audience"
    }
}
catch
{
    # If the variables could not be loaded, display a warning and stop the script
    Write-Warning -Message "Could not load variables" -WarningAction Stop
}

$GlobalHeaders = @{
    "Content-Type" = "application/json"
    "x-keyfactor-requested-with" = "APIClient"
}

function Get-HttpHeaders {
    if ($Variables.Auth_Method -eq "oauth") {
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
            $headers = $GlobalHeaders.Clone()
            $headers["Authorization"] = "Bearer $token"
        } catch {
            Write-Error -Message "Failed to fetch OAuth token: $($_.Exception.Message)"
            throw
        }
        return $headers
    } else {
        $authInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Variables.keyfactorUser):$($Variables.keyfactorPassword)"))
        $headers = $GlobalHeaders.Clone()
        $headers["Authorization"] = "Basic $authInfo"
        return $headers
    }
}


function get-keyfactor{
    # Check if the Keyfactor API is reachable
    try {
        $response = Invoke-WebRequest -Uri "https://$($Variables.KEYFACTOR_DNS)/keyfactorapi/status/endpoints" -UseBasicParsing -Headers (Get-HttpHeaders) -Method Get
        if ($response.StatusCode -eq 200) {
            return $true
        }
    } catch {
        Write-Warning -Message "Keyfactor API is not reachable. Please check the KEYFACTOR_DNS variable." -WarningAction Stop
    }
}

# Retrieve Agent Id
function Get-AgentId
{
    Write-Information -MessageData "Retrieving Orchestrator ID..." -InformationAction Continue
    $queryString = "ClientMachine%20-eq%20%22$($Variables.Orchestratorname)%22%20AND%20Status%20-eq%201"
    $url = "https://$($Variables.KEYFACTOR_DNS)/keyfactorapi/Agents?QueryString=$queryString"

    try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers (Get-HttpHeaders)
        return $response.AgentId
    } catch {
        Write-Error -Message "Error in Get-AgentId: $($_.Exception.Message)"
        throw
    }
}


# Function: Approve Agent
function ApproveAgent 
{
    try
    {
        Write-Information -MessageData "Approving Orchestrator" -InformationAction Continue
        $Body = '["' + $(Get-AgentId) + '"]'
        $FullPostUrl = "https://$($Variables.KEYFACTOR_DNS)/keyfactorapi/agents/approve"
        $Results = Invoke-WebRequest -Uri $FullPostUrl -Headers (Get-HttpHeaders) -Method Post -Body $Body
        if ($Results.StatusCode -eq 204)
        {
            Write-Information -MessageData "Orchestrator approved successfully." -InformationAction Continue
        }
        else
        {
            Write-Warning -Message "Failed to approve Orchestrator. Status code: $($Results.StatusCode)" -WarningAction Stop
        }
    } catch {
        Write-Error -Message "Error in ApproveAgent: $($_.Exception.Message)"
        throw
    }
    return $true
}

# Function to securely generate service credentials
function Get-ServiceCredential
{
    # Convert the plain text password into a SecureString for security
    $SecurePassword = ConvertTo-SecureString $Variables.servicePassword -AsPlainText -Force

    # Return a PSCredential object using the username and secure password
    return New-Object System.Management.Automation.PSCredential ($Variables.serviceUser, $SecurePassword)
}

# Function to streamline and execute the install process
function Run_InstallScript
{
    # Construct the base URL for the Keyfactor API
    $BaseUrl = "https://$($Variables.KEYFACTOR_DNS)/KeyfactorAgents"

    # Branch logic based on the authentication method
    if ($Variables.Auth_Method -eq "oauth")
    {
        # Define parameters for OAuth authentication
        $TokenParams = @{
            URL              = $BaseUrl                  # Base URL for authentication
            BearerTokenUrl   = $Variables.token_url      # Token endpoint URL
            ClientId         = $Variables.client_id      # OAuth client ID
            OrchestratorName = $Variables.Orchestratorname # Keyfactor orchestrator name
            Capabilities     = "all"                     # Grant all capabilities
            Force            = $true                     # Force the installation process
            Verbose          = $Variables.Debug          # pring Verbose statements for troubleshooting
            NoRevocationCheck= $true                     # remove revocation check of Keyfactor certificate
        }
        if ($Variables.audience)
        {
            $TokenParams.Audience = $Variables.audience  # Add audience if specified
        }
        if ($Variables.scope)
        {
            $TokenParams.Scope = $Variables.scope        # Add scope if specified
        }
        if ($Variables.inplace)
        {
            $TokenParams.InPlace = $Variables.InPlace
        }
        if ($Variables.client_secret)
        {
            $TokenParams.ClientSecret = ConvertTo-SecureString $Variables.client_secret -AsPlainText -Force
        }
        # Add service account credentials if they are used
        if ($Variables.use_service_account)
        {
            $TokenParams.ServiceCredential = Get-ServiceCredential
        }

        # Execute the installation script with OAuth parameters
        .\install.ps1 @TokenParams | Out-Null
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error -Message "Installation script failed with exit code $LASTEXITCODE." -ErrorAction Stop
        }
        else {
            Write-Information -MessageData "Installation script completed successfully." -InformationAction Continue
        }
    }
    else
    {
        # Generate Keyfactor credentials for basic authentication
        $CredKeyfactor = Get-ServiceCredential -Username $Variables.keyfactorUser -Password $Variables.keyfactorPassword

        # Define parameters for basic authentication
        $BasicParams = @{
            URL              = $BaseUrl                  # Base URL for authentication
            WebCredential    = $CredKeyfactor            # Web credential object
            OrchestratorName = $Variables.Orchestratorname # Keyfactor orchestrator name
            Capabilities     = "all"                     # Grant all capabilities
            Force            = $true                     # Force the installation process
            Verbose          = $Variables.Debug          # pring Verbose statements for troubleshooting
            NoRevocationCheck= $true                     # remove revocation check of Keyfactor certificate
        }

        # Add service account credentials if they are used
        if ($UseServiceAccount)
        {
            $BasicParams.ServiceCredential = Get-ServiceCredential
        }
        if ($Variables.inplace)
        {
            $TokenParams.InPlace = $Variables.InPlace
        }

        # Execute the installation script with basic authentication parameters
        .\install.ps1 @BasicParams
    }
}

Write-Information -MessageData "Starting Orchestrator Installation" -InformationAction Continue
write-Information -MessageData "Checking Connection to Keyfactor" -InformationAction Continue
#test connection to keyfactor
if (get-keyfactor)
{
    Write-Information -MessageData "Connection to Keyfactor API successful." -InformationAction Continue
}
else
{
    Write-Warning -Message "Failed to connect to Keyfactor API. Please check the KEYFACTOR_DNS variable." -WarningAction Stop
}

# Check if the installation script file exists in the specified path
if (Test-Path -Path "$($Variables.install_directory)/install.ps1")
{
    Set-Location -Path $Variables.install_directory

    # Run the installation script
    Run_InstallScript
}
else
{
    # Display a warning if the installation script cannot be found
    Write-Warning -Message "Cannot find the install.ps1 file, change the install_directory variable to directory where the Orchestrator files are located" -WarningAction Stop
}

if ($Variables.AutoApprove -eq $true)
{
    # If AutoApprove is true, approve the agent in Keyfactor Command
    Write-Information -MessageData "Auto Approving Orchestrator" -InformationAction Continue

    if (ApproveAgent)
    {
        Write-Information -MessageData "Agent approved successfully." -InformationAction Continue
    }
    else
    {
        Write-Warning -Message "Failed to approve agent." -WarningAction Stop
    }
    Write-Information "Script Completed"
}
else
{
    Write-Information -MessageData "Auto Approve is set to false, skipping approval step" -InformationAction Continue
}
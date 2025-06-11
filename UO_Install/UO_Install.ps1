# Main Block
try
{
    # Define script level variables for the script using a hashtable
    $script:Variables = @{
        # API hostname for Keyfactor
        KEYFACTOR_HOSTNAME  = "https://customerurl.keryfactorpki.com/KeyfactorAPI"

        # name that will be seen in Keyfactor Command
        Orchestratorname    = "somename"

        #if trubleshooting you can run in debug mode bt changing the Debug variable to $true
        Debug               = $false
        # Directory where installation scripts are located
        install_directory   = "<installfiles>/InstallationScripts"

        # Boolean to determine if a service account is being used
        use_service_account = $false

        # Authentication method (Basic or OAuth)
        Auth_Method         = "oauth"

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

# Function to securely generate service credentials
function Get-ServiceCredential
{
    param (
        # Input username for the credential
        [string]$Username,
        # Input password for the credential
        [string]$Password
    )

    # Convert the plain text password into a SecureString for security
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    # Return a PSCredential object using the username and secure password
    return New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
}

# Function to streamline and execute the install process
function Run_InstallScript
{
    param (
        # Hashtable containing necessary script variables
        [hashtable]$Variables = $Variables,
        # Authentication method (e.g., basic or OAuth)
        [string]$AuthMethod = $Variables.Auth_Method,
        # Boolean to determine if a service account will be used
        [bool]$UseServiceAccount = $Variables.use_service_account
    )

    # Construct the base URL for the Keyfactor API
    $BaseUrl = "https://$($Variables.KEYFACTOR_HOSTNAME)/KeyfactorAgents"

    # Branch logic based on the authentication method
    if ($AuthMethod -eq "oauth")
    {
        # Define parameters for OAuth authentication
        $TokenParams = @{
            URL              = $BaseUrl                  # Base URL for authentication
            BearerTokenUrl   = $Variables.token_url      # Token endpoint URL
            ClientId         = $Variables.client_id      # OAuth client ID
            Scope            = $Variables.scope          # Scope of access
            Audience         = $Variables.audience       # Audience for the token
            OrchestratorName = $Variables.Orchestratorname # Keyfactor orchestrator name
            Capabilities     = "all"                     # Grant all capabilities
            ClientSecret     = $Variables.client_secret  # OAuth client secret
            Force            = $true                     # Force the installation process
            Verbose          = $Variables.Debug          # pring Verbose statements for troubleshooting
            NoRevocationCheck= $true                     # remove revocation check of Keyfactor certificate
        }

        # Add service account credentials if they are used
        if ($UseServiceAccount)
        {
            $TokenParams.ServiceCredential = Get-ServiceCredential -Username $Variables.serviceUser -Password $Variables.servicePassword
        }

        # Execute the installation script with OAuth parameters
        .\install.ps1 @TokenParams
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
            $BasicParams.ServiceCredential = Get-ServiceCredential -Username $Variables.serviceUser -Password $Variables.servicePassword
        }

        # Execute the installation script with basic authentication parameters
        .\install.ps1 @BasicParams
    }
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
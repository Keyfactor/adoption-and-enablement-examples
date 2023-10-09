<#

#   KEYFACTOR PREREQUISITE VALIDATION SCRIPT
#   October 2023
#
#   This script has been developed by Keyfactor to assist customers with validating a server's
#   readiness for installing the following:
#   
#     - Keyfactor Cloud Enrollment Gateway (v22.0.0+)
#     - Keyfactor Universal Orchestrator (v10.0.0+)
#
#   This script does not configure or install any prerequisite or settings on the server.
#   Doing so is the sole responsibility of the customer executing this script.
#
#   Upon execution, this script prompts you to choose which Keyfactor component will be installed.
#   Additionally, you will be asked to provide some additional information that will allow the
#   script to accurately evaluate that the appropriate prequesites have been met.
#
#   These variables can optionally be uncommented and hard coded in the script, in case subsequant
#   runs are needed.
#
#   After checking for necessary prerequisites, this script displays test results as well as
#   "helper text" intended to help you resolve items that did not "PASS"

#>

#  ----------------------
# |  OPTIONAL VARIABLES  |
#  ----------------------
#region 

# GENERAL Variables
# - Uncomment the variables below if you wish to avoid entering them interactively.
# $Keyfactor_Command_Domain = "https://<domain>.keyfactorpki.com"
# $Validate_Orchestrator = $true                             # Validate Orchestrator Prerequisites
# $Validate_CloudGateway = $true                             # Validate Cloud Enrollment Gateway Prerequisites

# ORCHESTRATOR Variables
# - Uncomment the SECTION below if you wish to avoid entering them interactively.
<#  # Variables for CA Connectivity tests
    $Orchestrator_CheckCAConnectivity = $true                # This should be set to false unless you plan to sync on-premise CA's with the Keyfactor Universal Orchestrator
    $Orchestrator_CAs_to_Test = @(                           # One or multiple certificate authorities to test connectivity for, if the "CheckCAConnectivity" setting is TRUE.
        'myCAhostname.domain.com'
        #'<ca hostname>/<ca logical name>'
    )
#>
# $Orchestrator_ServiceAccount = 'NT AUTHORITY\NETWORK SERVICE" # Which account the Orchestrator will be ran as.


# CLOUD ENROLLMENT GATEWAY Variables
# $CEGW_SyncOnly = $false                                    # Whether to only validate the prequisites of the Keyfactor Enollment Gateway Sync Service
# $CEGW_ServiceAccount = 'NT AUTHORITY\NETWORK SERVICE'      # Which account the Cloud Gateway will be ran as.

#endregion

#  ----------------------
# |  SCRIPT PREFERENCES  |
#  ----------------------
#region

# CLOUD ENROLLMENT GATEWAY #
$CEGW_Supported_OS = @('2016','2019','2022')                 # Supported Windows Server versions
$CEGW_dotNetFW_MinVersion = 461808                           # Minimum supported version of the .NET Framework
$CEGW_templateAccess_limit = 35                              # Max number of certificate templates to test read access.

# UNIVERSAL ORCHESTRATOR #
$Orchestrator_Supported_OS = @('2019','2022')                # Supported Windows Server versions
$Orchestrator_dotNetCore_MinVersion = '6.0'                  # Minimum supported versions of .NET Core

# GENERAL #
#$validation_result_path = "C:\temp\validation_results.csv"  # Optionally hardcoded result filepath. By default, the file will be created where this script is located.

# HELPER Texts #
# The helper texts below are intended to provide context and remediation suggestions for failed tests.
# dotNet Core 
$Helper_DotNetCore = '
    The .NET Core runtime can be downloaded from Microsoft at:
    "https://dotnet.microsoft.com/download/dotnet/6.0/runtime"
    If you just installed .NET Core, ensure all PowerShell windows
    have been closed prior to trying this script again.
'
# dotNet Framework 
$Helper_DotNetFramework = '
    The .NET Framework can be installed as a Windows Server feature or downloaded from Microsoft
    at "https://dotnet.microsoft.com/en-us/download/dotnet-framework"
'
# Keyfactor Connection
$Helper_KeyfactorConnection = '
    This server needs network connectivity to your Keyfactor Command instance,
    which is either hosted in the Keyfactor Cloud or within your internal network.
    - If this server does not have internet access, your network team might be able
      to help by whitelisting traffic to your Keyfactor Command domain.
    - If this server is able to reach your Keyfactor Command domain via a web browser,
      but the connection test failed in this script, it is most likely caused by a proxy
      server within your organization.
'
# Proxy Disclaimer
$Helper_Proxy = '
   This script may not have been able to correctly detect your proxy configuration.
   Proxy implementations can vary greatly. If you are able to access your Keyfactor
   environment from a web browser on this server, but receive this message, additional
   configuration for your proxy will be needed. Potential options are creating HTTP_PROXY 
   environment variables, updating a Keyfactor config file (post installation), or another
   method specific to your proxy provider.
'
# Certificate Authority connectivity
$Helper_CAConnectivity = '
    This server needs network connectivity to your certificate authority if you plan to sync
    certificates via the Universal Orchestrator. If this test failed, it is most likely
    RPC (TCP 135) and/or DCOM (RPC Dynamic Port Range)(TCP 49152-65535) are being blocked
    by either a network firewall between the servers or the Windows firewall.
'
# Active Directory PowerShell Module
$Helper_ADModule = '
    The Active Directory PowerShell module is a component of the Remote Server Administrator Tools (RSAT),
    which can be installed as a Windows Server feature.
'
# ADWS Connectivity
$Helper_ADWS_Connection = '
    The Cloud Gateway Sync Services needs network connectivity to Active Directory Web Services (TCP 9389).
    This script tests connectivity to the domain that this server is joined to.
'
# RPC/DCOM Firewall rules
$Helper_RPC_DCOM = '
    The Cloud Gateway service receives certificate enrollment requests from workstations within your environment,
    similarly to a Microsoft Certificate Authority. Inbound network traffic for RPC (TCP 135) and
    DCOM (TCP 49152-65535) must be allowed FROM clients TO this server, by network firewalls and Windows Server.
    This script only validates an appropriate rule exist for the Windows Firewall.
'
# Entrust CRL Connectivity
$Helper_Entrust_CRL = '
    Deployed Keyfactor services (CEGW,Orchestrator) that connect to your Keyfactor-hosted environment
    require connectivity to perform revocation checks with the 3rd party provider (Entrust) that has
    issued the SSL certificate for your Keyfactor Command portal. The Entrust CRL domain is "crl.entrust.net"
'
# Logon-As-Service
$Helper_LogonAsService = '
    The service account used to run the Keyfactor service requires the "Logon As A Service" permission.
    This can be reviewed by navigating to:
    
    -> Administrative Tools -> Local Security Policy
       -> Local Policies -> User Rights Assignments
          --> Logon as a Service.

    You might need to contact the appropriate team that administers AD Group Policy to make this change.
'

#endregion

#  -------------
# |  FUNCTIONS |
#  -------------
#region

# Function to display formatted test results
function Write-ValidationResults{
    param(
        [hashtable]$hashtable
    )

    # Write header
    Write-Host -BackgroundColor Black "Result`t`tValidated Item"

    # Loop through results hashtable and print the status
    foreach($prerequisite in ($hashtable.keys | Sort-Object)){
    
        # Value
        $prerequisite_value = $hashtable[$prerequisite]    
    
        IF($prerequisite_value -eq $true){
            Write-Host  -ForegroundColor Green "PASS" -NoNewline
        }ELSEIF($prerequisite_value -eq $false){
            Write-Host -ForegroundColor Red "FAIL" -NoNewline
        }ELSEIF($prerequisite_value -eq "Review"){
            Write-Host -ForegroundColor YELLOW "REVIEW" -NoNewline
        }

        Write-Host `t`t -NoNewline
        Write-Host $prerequisite

    }
}

<# 

Confirm-Proxy.ps1
-------------------------------------------------------------------------------------------------
.NOTES
    Modified on:    08/14/2023
    Created by:     Elena Fiocca
    Organization:   Keyfactor
    Version:        1.0.1
    Comments:       1) Added boolean return value (Success/Failure)
                    2) Updated function name to use PS cmdlet approved verb

    Created on:     04/10/2023
    Created by:     Elena Fiocca
    Organization:   Keyfactor
    Version:        1.0.0 (Major.Minor.Bug)
 
.DESCRIPTION 
    This function checks for a proxy configuration. 
    - Retrieve the Windows system environment variables, HTTP_PROXY and HTTPS_PROXY, for proxy definition

    Limitations:
    1. N/A
    
    Future Enhancements:
    1. N/A

.EXAMPLE
    PS> Confirm-Proxy

.OUTPUTS
    Function Return Value: True/False boolean indicating the check passed

    Function Console Output:

    Output will be a message indicating the following states -
    1. Proxy is configured
        a) List HTTP proxy
        b) List HTTPS proxy
    2. No proxy is configured
-------------------------------------------------------------------------------------------------
#>
function Confirm-Proxy
{
    [CmdletBinding()]
    param()

    # Set the default function result
    $result = $false

    try 
    {
        # Retrieve the following Windows system environment variables to check for existence of a proxy 
        $httpProxy = [Environment]::GetEnvironmentVariable("HTTP_PROXY")
        $httpsProxy = [Environment]::GetEnvironmentVariable("HTTPS_PROXY")

        # Retrieve a proxy definition using the network shell 
        $networkProxy = netsh winhttp show proxy

        # Proxy definition is configured
        if($httpProxy -or $httpsProxy) 
        {
            Write-Host "A proxy is configured"
            $result = $true

            if($httpProxy)
            {
                Write-Host "`t* HTTP Proxy: $httpProxy"
            }
            if($httpsProxy)
            {
                Write-Host "`t* HTTPS Proxy: $httpsProxy"
            }
        }
        elseif ($networkProxy -like '*proxy server(s)*' -split ' +: +', 2)
        {
            Write-Host "A proxy is configured"
            $result = $true
        }
        # No proxy is configured
        else 
        {
            Write-Host "No proxy is configured"
        }
    }
    catch  
    {
        $e = $_.exception
        $line = $_.InvocationInfo.ScriptLineNumber
        $msg = $e.message

        Write-Host "An error occurred in the Confirm-Proxy function" -ForegroundColor red 
        $text = "`tException Occurred at Line: " + $line + "`r`n`tMessage: " + $msg
        Write-Host $text -ForegroundColor red 
    }

    return $result
}

Function Get-RegValue
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,HelpMessage='Path to the registry setting')][string]$regPath,
        [Parameter(Mandatory,HelpMessage='Name of the registry key')][string]$regName
    )

    $result = $false

    $regItem = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Ignore
    $output = "" | Select-Object Path, Name, Value
    $output.Path = $regPath
    $output.Name = $regName

    if ($null -eq $regItem) 
    {
        $output.Value = "Not Found"
    }
    else 
    {
        if ($regItem.$regName -eq 0)
        {
            $output.Value = 'False'
        }
        else 
        {
            $output.Value = 'True'
            $result = $true
        }
    }
    $output

    return $result
}

<# 

Confirm-DotNetRuntime.ps1
-------------------------------------------------------------------------------------------------
.NOTES
    Modified on:    08/11/2023
    Modified by:    Forrest McFaddin
    Organization:   Keyfactor
    Version:        1.0.1
    Comments:       1) Fixed bug with version comparison if environment has more than one version of
                       .NET installed
                    2) Added boolean return value (Success/Failure)
                    3) Updated function name to use PS cmdlet approved verb

    Created on:     03/29/2023
    Created by:     Elena Fiocca
    Organization:   Keyfactor
    Version:        1.0.0 (Major.Minor.Bug)
 
.DESCRIPTION 
    This function checks for a specific .NET Runtime installation on a client machine and compares the
    installed version to a minimum required version. 

    A .NET Runtime allows you to run compiled code.

.PARAMETER Runtime
    The .NET runtime installation to verify

.PARAMETER MinVersion
   The minimum required version of the .NET Runtime to be installed 

.EXAMPLE
    PS> Confirm-DotNetRuntime -Runtime Microsoft.NETCore.App -MinVersion 6.0
    Checks if Microsoft.NETCore.App runtime is installed and the version is at least 6.0.

    Other .NET Runtime examples:
    Microsoft.AspNetCore.App
    Microsoft.WindowsDesktop.App

.OUTPUTS
    Function Return Value: True/False boolean indicating the check passed

    Function Console Output:

    Message indicating the following states -
    1. .NET Runtime installed meets the minimum required version 
    2. .NET Runtime installed does NOT meet the minimum required version
    3. .NET Runtime is NOT installed
-------------------------------------------------------------------------------------------------
#>
function Confirm-DotNetRuntime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,HelpMessage='.NET Runtime to verify')][string]$Runtime,
        [Parameter(Mandatory,HelpMessage='Minimum required .NET Runtime version, i.e. 6.0.1')][string]$MinVersion
    )

    # Set the default function result
    $result = $false

    try 
    {
        # Check if the 'dotnet' PS cmdlet is available
        if(-Not (Get-Command dotnet -ErrorAction SilentlyContinue))
        {
            throw "The 'dotnet' cmdlet is not available and is required for this function. Try installing the .NET Core SDK."
        }

        $dotNetRuntimes = dotnet --list-runtimes | Select-String -Pattern "^$Runtime\s"

        #.NET Runtime version is installed
        if($dotNetRuntimes) 
        {
            foreach($installedRuntime in $dotNetRuntimes)
            {
                # Isolate the version number
                $installedVersion = $installedRuntime.ToString().Split(" ")[1]

                # Parse Major/Minor/Bug versions for installed and defined minimum versions
                $installedVersion_major = [int]$installedVersion.Split(".")[0]
                $installedVersion_minor = [int]$installedVersion.Split(".")[1]
                $installedVersion_bug = [int]$installedVersion.Split(".")[2]
                $MinVersion_major = [int]$MinVersion.Split(".")[0]
                $MinVersion_minor = [int]$MinVersion.Split(".")[1]
                $MinVersion_bug = [int]$MinVersion.Split(".")[2]

                 # Check Major version
                 if($installedVersion_major -ge $MinVersion_major)
                 {
                     # Check Minor version
                     if($installedVersion_minor -ge $MinVersion_minor)
                     {
                         # Check Bug version
                         if($installedVersion_bug -ge $MinVersion_bug)
                         {
                             $version_valid = $true
                             $result = $true
                         }
                         # Reverse lookups for minor/major versions
                         elseif($installedVersion_minor -gt $MinVersion_minor)
                         {
                             $version_valid = $true
                             $result = $true
                         }
                         elseif($installedVersion_major -gt $MinVersion_major)
                         {
                             $version_valid = $true
                             $result = $true
                         }
                         else
                         {
                             $version_valid = $false
                         }
                     }
                     elseif($installedVersion_major -gt $MinVersion_major)
                     {
                         $version_valid = $true
                         $result = $true
                     }
                     else
                     {
                         $version_valid = $false
                     }
                 }
                 else
                 {
                     $version_valid = $false
                 }

                # Print the result
                if($version_valid -eq $true)
                {
                    Write-Host ".NET Runtime $runtime $installedVersion is installed and above the required minimum version!"
                }
                else
                {
                    Write-Host ".NET Runtime $runtime $installedVersion is installed, but is lower than the minimum required version $MinVersion"
                }
            } # End foreach
        }
        #.NET Runtime version is not installed
        else 
        {
            Write-Host ".NET Runtime $runtime is not installed"
        }
    }
    catch  
    {
        $e = $_.exception
        $line = $_.InvocationInfo.ScriptLineNumber
        $msg = $e.message

        Write-Host "An error occurred in the Confirm-DotNetRuntime function" -ForegroundColor red 
        $text = "`tException Occurred at Line: " + $line + "`r`n`tMessage: " + $msg
        Write-Host $text -ForegroundColor red 
    }

    return $result
}

<# 

Confirm-DotNetFramework.ps1
-------------------------------------------------------------------------------------------------
.NOTES
    Modified on:    08/14/2023
    Created by:     Elena Fiocca
    Organization:   Keyfactor
    Version:        1.0.1
    Comments:       1) Added boolean return value (Success/Failure)
                    2) Updated function name to use PS cmdlet approved verb

    Created on:     03/29/2023
    Created by:     Elena Fiocca
    Organization:   Keyfactor
    Version:        1.0.0 (Major.Minor.Bug)
 
.DESCRIPTION 
    This function checks for a specific release of the .NET Framework on a client machine and compares the
    release version to a minimum required version. 

    .NET Framework is a set of assemblies, namespaces, and classes you can use to create applications.

    Limitations:
    1. This function only verifies .NET Framework installs for 64-bit Windows OS
    2. User MUST know the decimal value representation of the release number for the minimum required version
    
    Future Enhancements:
    1. Add .NET Framework release lookup table to determine the decimal representation of the release from the string value 
    2. Convert the .NET Framework string version number to its decimal representation

.PARAMETER MinVersion
   The minimum required version of the .NET Framework to be installed.
   Version MUST be represented as its decimal equivalent.   

   .NET Framework | Release Value (Decimal)
   ==========================================
            4.6.2 | 394802 or 394806
            4.7   | 460805
            4.7.1 | 461308 or 461310
            4.7.2 | 461808 or 461814
            4.8   | 528040,528049,528372, or 528449

.EXAMPLE
    PS> Confirm-DotNetFramework -MinVersion 460805
    Checks if .NET Framework is installed and the version is at least 460805 (or 4.7).

.OUTPUTS
    Function Return Value: True/False boolean indicating the check passed

    Function Console Output:

    Output will be a message indicating the following states -
    1. .NET Framework installed meets the minimum required version 
    2. .NET Framework installed does NOT meet the minimum required version
    3. .NET Framework is NOT installed
-------------------------------------------------------------------------------------------------
#>
function Confirm-DotNetFramework
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,HelpMessage='Minimum required .NET Framework version represented as a decimal, i.e. 460805')][string]$MinVersion
    )

    # Set the default function result
    $result = $false

    try 
    {
        # Check registry for .NET Framework installation
        $dotNetFramework = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name Release -ErrorAction SilentlyContinue

        #.NET Framework is installed
        if($dotNetFramework) 
        {
            $installedVersion = $dotNetFramework.Release
            
            #.NET Framework meets minimum required version
            if($installedVersion -ge $MinVersion) 
            {
                Write-Host ".NET Framework $installedVersion is installed and above the required minimum version!"
                $result = $true
            }
            #.NET Framework does NOT meet minimum required version
            else 
            {
                Write-Host ".NET Framework $installedVersion is installed, but is lower than the minimum required version $MinVersion"
            }
        }
        #.NET Framework is not installed
        else 
        {
            Write-Host ".NET Framework is not installed"
        }
    }
    catch  
    {
        $e = $_.exception
        $line = $_.InvocationInfo.ScriptLineNumber
        $msg = $e.message

        Write-Host "An error occurred in the Confirm-DotNetFramework function" -ForegroundColor red 
        $text = "`tException Occurred at Line: " + $line + "`r`n`tMessage: " + $msg
        Write-Host $text -ForegroundColor red 
    }

    return $result
}

# Function to test connection to Keyfactor
function Test-KeyfactorConnection($url,$parent_domain){
    
    $result = $false
    $content = $null
    $response_host = $null

    ################
    # Code Reference
    # Disabling validation callback via C#, which is more reliable when subsequent tests are performed.
    # https://stackoverflow.com/questions/41897114/unexpected-error-occurred-running-a-simple-unauthorized-rest-query
    
    #C# class to create callback
    $code = '
    public class SSLHandler
    {
        public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
        {
            return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
        }    
    }
    '

    #compile the class
    try
    {
        Add-Type -TypeDefinition $code
    }
    Catch{}

    #disable checks using new class
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
    #do the request
    try
    {
        invoke-WebRequest -Uri myurl -UseBasicParsing
    } catch {
        # do something
    } finally {
       #enable checks again
       [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }

    ### End Code reference
    ######################

    try
    {
        $content = Invoke-WebRequest -uri $url -Method Get -UseBasicParsing -ErrorAction Stop -TimeoutSec 8
        $response_host = ($content.BaseResponse.ResponseUri.Host)
    }
    Catch
    {
        Write-Host -ForegroundColor Red "Could not reach the URL"
        Write-Host $_
    }
    IF($response_host -like ("*." + $parent_domain + ".*"))
    {
        $result = $true
        Write-Host "Successfully reached $url"
    }ELSE
    {
        
    }
    return $result
}

# Function to return accounts listed in "Logon as Service" sec pol permissions.
function Get-SecPermissions-LogonAsService
{
    # Define privilege
    $privilegeName = "SeServiceLogonRight"

    # Export sec privileges
    try
    {
        $privileges = (secedit /export /areas USER_RIGHTS /cfg "$env:temp\user_rights.inf")
    }
    Catch
    {
        throw "Couldn't export security policy config for validation"
    }

    # Get content
    $sec_content = Get-Content -Path "$env:temp\user_rights.inf"

    # Select the 
    $logonAs_permission = [string]($sec_content | Select-String -Pattern ("^$privilegeName ="))
    $logonAs_objects = $logonAs_permission.Split("=")[1].Split(",")

    $result_accounts = @()
    foreach($p in $logonAs_objects)
    {
        $string = [string]$p
        IF($string -match " *")
        {
            $sid = ($string.Replace(" *",""))
        }
        IF($string[0] -eq "*")
        {
            $sid = ($string.Replace("*",""))
        }

            try
            {
                $account_name = ((New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount])).Value
                $result_accounts += $account_name
            }
            Catch
            {
                "SID could not be translated"
            }
    }
    return $result_accounts
}

# Function to test CA Connectivity via a certutil command.
function Test-CAConnection
{
param(
    [string]$CA
)
    $certutil_test = $null
    $certutil_test = (CertUtil -ping $($CA))

    # Normal Ping
    IF($certutil_test -like "*alive*" -and $certutil_test -like "*completed successfully*")
    {
        Write-Host "Successfully pinged Certificate Authority: $CA"
        $result = $true
    }
    # Network Service Ping
    IF($result -ne $true){
        $certutil_test = (CertUtil -ping -config $($CA) -sid 24)
        IF($certutil_test -like "*alive*" -and $certutil_test -like "*completed successfully*")
        {
            Write-Host "Successfully pinged Certificate Authority: $CA via NETWORK SERVICE"
            Write-Host -ForegroundColor Yellow "This could indicate an issue with the permissions of the current user,"
            Write-Host -ForegroundColor Yellow "since the initial Certutil -ping test failed."
            $result = "Review"
        }
    }
    IF($certutil_test -like "*server could not be*")
    {
        Write-Host -ForegroundColor Red "Unable to connect to CA: $CA"
        Write-Host -ForegroundColor Yellow "Provide either the FQDN of the certificate authority or <hostname>\<ca logical name> together"
        $result = $false
    }
    ELSEIF($certutil_test -like "*RPC Server unavailable*")
    {
        Write-Host -ForegroundColor Red "Unable to connect to CA: $CA"
        Write-Host -ForegroundColor Yellow "The RPC connection failed. Ensure this server is able to"
        Write-host -ForegroundColor Yellow " communicate to $CA on TCP 135 (RPC) and TCP 49152-65535 (RCP Dynamic Range)"
        $result = $false
    }
    return $result
}

# Function to confirm if a Windows Firewall rule exist to allow an inbount port.
function Confirm-InboundPort-Allowed{

    param(
        [string][parameter(Mandatory,HelpMessage='Local port (inbound) that firewall rule allows. TCP Port number or Name of protocol (e.g. "RPC")')]$LocalPort,
        [string][parameter(Mandatory,HelpMessage='Local port (inbound) that firewall rule allows. TCP Port number or Name of protocol (e.g. "RPC")')]$RemotePort
    )

    $ports = $null
    $enabled_rules = $null
    $rull = $null

    # Get firewall ports that either match the provided ports or which include them.
    $ports = (Get-NetFirewallPortFilter -Protocol TCP | where {$_.RemotePort -eq $local_port_in -or $_.RemotePort -eq "Any" -or $_.RemotePort -like "*-*"})
    $enabled_rules = Get-NetFirewallRule -Enabled True -Action Allow -Direction Inbound

    foreach($p in $ports)
    {
        $remote_valid_port = $true
        $local_valid_port = $true

        # Check Remote Port of the rule includes a range
        IF($p.RemotePort -like "*-*")
        {

            $remote_start_range = $p.RemotePort.Split("-")[0]
            $remote_end_range = $p.RemotePort.Split("-")[1]

            # If a range exist and the provided port is outside of the range
            IF($RemotePort -lt $remote_start_range -or $RemotePort -gt $remote_end_range)
            {
                $remote_valid_port = $false
            }
        # Else, if the port is not what was provided nor is "ANY"
        }
        ELSEIF($p.RemotePort -ne $RemotePort -and $p.RemotePort -ne "Any")
        {
            $remote_valid_port = $false 
        }
        ELSE
        {
            $remote_valid_port = $true
        }

        # Check Local Port of the rule includes a range
        IF($p.LocalPort -like "*-*")
        {
            $local_start_range = $p.LocalPort.Split("-")[0]
            $local_end_range = $p.LocalPort.Split("-")[1]

            # If a range exist and the provided port is outside of the range
            IF($LocalPort -lt $local_start_range -or $LocalPort -gt $local_end_range)
            {
                $local_valid_port = $false    
            }
        # Else, if the port is not what was provided nor is "ANY"
        }
        ELSEIF($p.LocalPort -ne $LocalPort  -and $p.LocalPort -ne "Any")
        {
            $local_valid_port = $false
        }
        ELSE
        {
            $local_valid_port = $true
        }
        # If the port is not valid, continue to evaluate valid rules, considering programs.
        IF($local_valid_port -ne $false -and $remote_valid_port -ne $false)
        {
            $rule = ($enabled_rules | where {$_.Name -eq $p.InstanceID -and $_.Action -eq "Allow" -and $_.Direction -eq "Inbound"})
            IF($rule)
            {
                $app = $Rule | Get-NetFirewallApplicationFilter
                IF($app.AppPath -like "*Keyfactor*" -or $app.AppPath -eq "Any" -or $app.AppPath -eq "System" -or $app.AppPath -eq "%systemroot%\system32\svchost.exe")
                {
                    Write-host ("["+$p.RemotePort+"]") $rule.Direction $rule.Enabled $rule.Profile $rule.DisplayName
                    Write-Host ("Application: "+$app.Program)
                    return $true                    
                }
            }
        }
    }
    return $false
}

function Test-OutboundPort
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false,HelpMessage='The FQDN or IP address of the outbound target')][string]$Target,
        [Parameter(Mandatory,HelpMessage='The port to verify connectivity over to the target')][string]$Port
    )
    
    # Set the default function result
    $result = $false

    try 
    {
        # Check the outbound connection to the target server and output the result
        if([string]::IsNullOrEmpty($Target))
        {
            $connResult = Test-NetConnection -Port $Port

            if($connResult.TcpTestSucceeded)
            {
                Write-Host "General Outbound Connection via port $Port - OPEN"
                $result = $true
            }
            else
            {
                Write-Host "General Outbound Connection via port $Port - CLOSED"
            }
        }
        else
        {
            $connResult = Test-NetConnection -ComputerName $Target -Port $Port

            if($connResult.TcpTestSucceeded)
            {
                
                Write-Host "Outbound Connection to $Target via port $Port - OPEN"
                $result = $true
            }
            else
            {
                Write-Host "Outbound Connection to $Target via port $Port - CLOSED"
            }
        }        
    }
    catch  
    {
        $e = $_.exception
        $line = $_.InvocationInfo.ScriptLineNumber
        $msg = $e.message

        Write-Host "An error occurred in the Test-OutboundPort function" -ForegroundColor red 
        $text = "`tException Occurred at Line: " + $line + "`r`n`tMessage: " + $msg
        Write-Host $text -ForegroundColor red 
    }

    return $result
}

# Function to validate Entrust CRL is reachable
function Test-EntrustCRL{
    $entrust_crl = 'http://crl.entrust.net/level1k.crl'
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    # Create a web request for a known Entrust CRL URI
    $webRequest = $null
    $webRequest = [Net.HttpWebRequest]::Create($entrust_crl)
    # Set timeout to 5 seconds
    $webRequest.Timeout = 5000
    try
    {
        $response = $webRequest.GetResponse()
        IF($response.StatusCode -eq "OK")
        {
            Write-Host "Successfully reached the Entrust CRL: $entrust_crl"
            return $true
        }
        ELSE
        {
            Write-Host -ForegroundColor Red "The Entrust CRL could not be reached."
            return $false
        }
    }
    Catch
    {
            Write-Host -ForegroundColor Red "The Entrust CRL could not be reached."
            return $false    
    }
}

# Function to confirm the OS version is supported by the application
function Confirm-OSMinimumVersion
{
    param(
        [array]$Supported_OS
    )
    
    # Get this server's OSName
    #$OSName = (Get-ComputerInfo -Property OSName)
    $OSName = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue("ProductName")

    #$OSVersion = $OSName.OsName.Split(" ")
    $OSVersion = $OSName.Split(" ")
    $OSVersion = $OSVersion.Where({$_ -like "2*"})
    
    IF($OSVersion -in $Orchestrator_Supported_OS){
        Write-Host "Detected Windows Server version $OSVersion, which is supported."
        $result = $true
    }
    ELSE
    {
        Write-Host -ForegroundColor Red "This script detected another OS version that is not supported."
        Write-Host -ForegroundColor Yellow "Supported Windows Server versions are: $Orchestrator_Supported_OS"
        $result = $false
    }
    return $result
}

# Function to confirm AD PowerShell module is installed
function Confirm-ADPSModule{
    try
    {
        Import-Module "ActiveDirectory" -ErrorAction Stop
        $AD_Command = (Get-Command -Name "Get-ADGroup" -ErrorAction Stop)
        IF($AD_Command)
        {
            Write-Host "Active Directory PowerShell module is installed."
            return $true
        }
    }
    Catch
    {
        Write-Host -ForegroundColor Red "Active Directory PowerShell module is not installed."
        return $false
    }
}

# Function to retrieve AD certificate templates from the domain this server is joined to.
function Get-ADCertificateTemplates
{
    # Define template location
    $ConfigContext = ([ADSI]"LDAP://RootDSE").configurationNamingContext
    $ConfigContext = "LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"        

    # Search the directory
    $TemplateSearch = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$ConfigContext)
    $TemplateSearch.Filter = "(objectClass=pKICertificateTemplate)"
    try
    { 
        $results = $TemplateSearch.FindAll()
    }
    Catch
    {
        Write-Host -ForegroundColor Red "Issue with performing certificate template query"       
    }
    IF($results -and $results.Count -gt 0)
    {
        Write-Host ("Queried Active Directory certificate templates with "+$results.count+" results")
        return $results
    }ELSE
    {
        Write-Host -ForegroundColor Red "No certificate templates were returned in the search"
        return $null
    }
}

<# 

Confirm-TemplateAccess-ReadEnroll.ps1
-------------------------------------------------------------------------------------------------
.NOTES
    Created on:     08/23/2023
    Created by:     Elena Fiocca
    Organization:   Keyfactor
    Version:        1.0.0 (Major.Minor.Bug)

    Contribution by: Vadims Podans
    Website: https://www.sysadmins.lv/blog-en/get-certificate-template-effective-permissions-with-powershell.aspx
 
.DESCRIPTION 
    This function determines the effective permissions for a user on a certificate template and will return TRUE
    if the user has both READ & ENROLL permissions on the certificate template. 

    The user will be identified by providing a UPN as a parameter to the function.
    If a UPN is not provided, the current user will be used.
    
.PARAMETER TemplateName
    The Template Name to which we are verifying READ & ENROLL access

.PARAMETER UPN
    OPTIONAL: The UPN used to verify READ & ENROLL access on a specific template (i.e. testuser@command.com)

.EXAMPLE
    PS> Confirm-TemplateAccess-ReadEnroll -Template KFWebServer_v1
    Verifies if the current user's effective permissions has READ & ENROLL access to the "KFWebServer_v1" certificate template

    PS> Confirm-TemplateAccess-ReadEnroll -Template KFWebServer_v1 -UPN testuser@command
    Verifies if "testuser" effective permissions has READ & ENROLL access to the "KFWebServer_v1" certificate template

.OUTPUTS
    Function Return Value: True if the user has READ & ENROLL access to a certificate template; False if the user does not

    Function Console Output:

    Output will be a message displaying the list of permissions the user has on the certificate template
-------------------------------------------------------------------------------------------------
#>
function Confirm-TemplateAccess-Read
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,HelpMessage='The Template Name to which we are verifying READ & ENROLL access')][string]$TemplateName,
        [Parameter(Mandatory=$false,HelpMessage='The UPN used to verify READ & ENROLL access to a template (i.e. testuser@command.com)')][string]$UPN
    )

    # Set the default function result
    $result = $false

    try 
    {
        # Get membership info for the user
        if ($UPN) 
        {
            $user = New-Object Security.Principal.WindowsIdentity -ArgumentList $UPN
        } 
        else 
        {
            $user = [Security.Principal.WindowsIdentity]::GetCurrent()
        }

        # Convert the user groups SIDs to NT Account classes
        $IDs = $user.Groups | ForEach-Object{$_.Translate([Security.Principal.NTAccount])}
        $IDs += $user.Name
        
        # Filter by the certificate Template Name provided
        $filter = "(cn=$TemplateName)"

        # Retrieve certificate template object from AD
        $ConfigContext = ([ADSI]"LDAP://RootDSE").configurationNamingContext
        $ConfigContext = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
        $ds = New-object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$ConfigContext",$filter)

        # Confirm templates are found.
        try
        {
        $Template = $ds.Findone().GetDirectoryEntry() | ForEach-Object{$_}
        }
        Catch
        {
            Write-Host -ForegroundColor Red "Templates could not be retrieved. Does the account running this script have access?"
            throw $_
        }

        $Accesses = @()
        $Accesses += $Template.ObjectSecurity.Access | ForEach-Object{
            $current = $_
            $Rights = @($current.ActiveDirectoryRights.ToString().Split(",",[StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object{$_.trim()})
            $GUID = $current.ObjectType.ToString()
            $current | Add-Member -Name Permission -MemberType NoteProperty -Value @()
            if ($Rights -contains "GenericRead") {$current.Permission += "Read"}
            if ($Rights -contains "WriteDacl") {$current.Permission += "Write"}
            if ($Rights -contains "GenericAll") {$current.Permission += "Full Control"}
            if ($Rights -contains "ExtendedRight") 
            {
                if ($GUID -eq "a05b8cc2-17bc-4802-a710-e7c15ab866a2") {$current.Permission += "Autoenroll"}
                elseif ($GUID -eq "0e10c968-78fb-11d2-90d4-00c04f79dc55") {$current.Permission += "Enroll"}
            }
            $current
        }
        $EffectiveDeny = $Accesses | Where-Object {$_.AccessControlType -eq "Deny"} | ForEach-Object {
            if ($IDs -contains $_.IdentityReference.ToString()) {
                IF($_.Permission){
                    $_.Permission    
                }ELSEIF($_.ActiveDirectoryRights -match "ReadProperty"){

                    "Read"
                }
            }
        }
        $EffectiveAllow = $Accesses | Where-Object {$_.AccessControlType -eq "Allow"} | ForEach-Object {
            if ($IDs -contains $_.IdentityReference.ToString()) {
                IF($_.Permission){
                    $_.Permission    
                }ELSEIF($_.ActiveDirectoryRights -match "ReadProperty"){
                    # The section is needed to add "Read" permissions that have been explicitly added to the account.
                    # The $_.permission propery does not include "Read" in this scenario.
                    "Read"
                }
            }
        }
        $EffectiveDeny = $EffectiveDeny | Select-Object -Unique
        $EffectiveAllow = $EffectiveAllow | Select-Object -Unique

        Write-Host "Read Permission for $UPN on $TemplateName"
        Write-Host "------------------------------------------------------"
        $EffectiveAllow = $EffectiveAllow | Where-Object {$EffectiveDeny -notcontains $_}

        # Verify that the user has both READ & ENROLL permissions on the certificate template
        $read = $EffectiveAllow | Where-Object {$_ -eq "Read"}        

        if($read)
        {
            $result = $true
        }
    }
    catch  
    {
        $e = $_.exception
        $line = $_.InvocationInfo.ScriptLineNumber
        $msg = $e.message

        Write-Host "An error occurred in the Confirm-TemplateAccess-Read function" -ForegroundColor red 
        $text = "`tException Occurred at Line: " + $line + "`r`n`tMessage: " + $msg
        Write-Host $text -ForegroundColor red 
    }

    return $result
}

# Function to clear Kerberos cached tickets, return the provided user's claims.
function Get-ADUserGroups{
    param(
        [string][parameter(mandatory)]$UPN
    )

    # Clearn Kerberos tickets
    try
    {
        $kp = klist purge
        IF($kp -like "*Command list:*"){
            throw "An error occurred while purging cached kerberos tickets."
        }
        #Write-Host "Purged cached kerberos tickets on this server to ensure user group accuracy"
    }
    Catch
    {
        Write-Host -ForegroundColor Yellow "Couldn't purge kerberos tickets to ensure user group accuracy"
        Write-Host $_
    }

    $groups = @()

    $user = New-Object Security.Principal.WindowsPrincipal -ArgumentList $UPN       
    
    # Translate each claim and add to the array
    foreach($sid in $user.Claims.value)
    {
        IF($sid -and $sid -notlike "*\*")
        {
            try
            {
                $group = (((New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount])).Value)
                IF($group)
                {
                    $groups += $group
                }
            }
            Catch
            {
                Write-Host "Couldn't translate sid: $sid"
            }
        }
    }
    return $groups
}

# Function to confirm if a user has the Logon As a Service permission.
function Confirm-UserLogonAsService
{
param(
    [Parameter(Mandatory,ValueFromPipeline)]
    [string]$UPN            
)

    # Confirm the provided value is UPN formatted
    IF($UPN -notmatch '^(?<username>[^@]+)@(?<domain>.+)')
    {
        Write-Host -ForegroundColor Yellow 'Provided value is not UPN formatted as "<username>@<domain>"'
        Write-Host -ForegroundColor Yellow 'Examples: svc_kf_orchestrator@domain.local / svc_kf_orchestrator$@domain.local'
        return $false
    }
    
    # Get User Groups
    $AD_Groups = (Get-ADUserGroups -UPN $UPN)

    # Get Logon As Service permissions
    $LogonAsService_Groups = (Get-SecPermissions-LogonAsService)

    # Set default result
    $result = $false

    # Check if user groups are among Logon As Service groups
    foreach($entry in $LogonAsService_Groups)
    {
        IF($entry -in $AD_Groups)
        {
            Write-host "$UPN has the Logon-As-Service permission through $entry"
            $result = $true
            break
        }
    }
    # Print a message if false
    IF($result -eq $false)
    {
        Write-Host "Couldn't identify the Logon-As-Service permission for $UPN"
    }
    return $result
}

#endregion

#  ----------------
# |  START SCRIPT  |
#  ----------------

# Prompt for installation type
IF(!$Validate_Orchestrator -and !$Validate_CloudGateway)
{
    # Define prompt options
    $validation_types = @(
        'Keyfactor Cloud Enrollment Gateway','Keyfactor Universal Orchestrator','Both'
    )

    # Print the options
    Clear-Host
    Write-Host "Select the application(s) that will be installed on this server:`n"
    Write-Host -ForegroundColor Yellow "`t[1]`t" -NoNewline
    Write-Host $validation_types[0]
    Write-Host -ForegroundColor Yellow "`t[2]`t" -NoNewline
    Write-Host $validation_types[1]
    Write-Host -ForegroundColor Yellow "`t[3]`t" -NoNewline
    Write-Host $validation_types[2]`n

    # Prompt for the users selection
    $validation_type_prompt = Read-Host -Prompt "Enter your choice from the list above (1,2,3)"

    IF($validation_type_prompt -ge 1 -and $validation_type_prompt -le 3)
    {
        IF($validation_type_prompt -eq 1 -or $validation_type_prompt -eq 3)
        {
            $Validate_CloudGateway = $true
            #region Check if this server will only run the CEGW sync service
            IF(!$CEGW_SyncOnly)
            {
                Write-Host -ForegroundColor Yellow "`n The Cloud Gateway is able to run 2 different services:"
                write-host -ForegroundColor Yellow "`t - Enrollment Gateway service:    Sends certificate requests to Keyfactor"
                Write-Host -ForegroundColor Yellow "`t - Keyfactor Sync service: Syncs Active Directory groups/users/certificate templates to Keyfactor"
                Write-Host -ForegroundColor yellow "`n If you have a Keyfactor CLAaaS environment, it is likely you only require the Sync service."
                $CEGW_Sync_Prompt = Read-Host -Prompt "`nWill this server only run the Keyfactor Cloud Gateway sync service? (Y/N)"
                IF($CEGW_Sync_Prompt -ilike "*y*")
                {
                    $CEGW_SyncOnly = $true
                }ELSE{
                    $CEGW_SyncOnly = $false
                }
            }#endregion

            #region Determine service account
            IF(!$CEGW_ServiceAccount)
            {
                # Prompt Y/N for default option
                Write-Host -ForegroundColor Yellow "`nThe Cloud Gateway service can run on this server as one of the following:"
                write-host -ForegroundColor Yellow "`t - NT AUTHORITY\NETWORK SERVICE  (default)"
                write-host -ForegroundColor Yellow "`t - Domain Account"
                write-host -ForegroundColor Yellow "`t - Group Managed Service Account (gMSA)"
                Write-Host -ForegroundColor yellow "`t Note: Keyfactor personell do not advise or support the creation of gMSAs within your Active Directory."

                $CEGW_ServiceAccount_Prompt = Read-Host -Prompt "`nWill the service use the default account of NT AUTHORITY\NETWORK SERVICE? (Y/N)"

                IF($CEGW_ServiceAccount_Prompt -inotlike "*y*")
                {
                    while(!$CEGW_ServiceAccount -and ($CEGW_ServiceAccount -notlike "*@*" -and $CEGW_ServiceAccount -notlike "*$"))
                    {
                        $CEGW_ServiceAccount = Read-Host -Prompt "Enter the UPN (<username>@<domain>) of the account that will run the service"
                    }
                }
            }
            #endregion
        }
        IF($validation_type_prompt -eq 2 -or $validation_type_prompt -eq 3)
        {
            $Validate_Orchestrator = $true
            # If CheckCAConnectivity is not set, prompt for it.
            IF(!$Orchestrator_CheckCAConnectivity)
            {
                Write-Host -ForegroundColor Yellow "`nThe Universal Orchestrator can sync your organization's certificates from internal Certificate Authorities."
                Write-Host -ForegroundColor Yellow "You do not require this functionality if your organization does not have internal CAs or will use the Keyactor Remote CA Gateway`n"
                $CASyncPrompt = Read-Host -Prompt "Will this Universal Orchestrator be used to sync your organization's Certificate Inventory? (Y/N)"

                IF($CASyncPrompt -ilike "*y*")
                {
                    $Orchestrator_CheckCAConnectivity = $true
                    IF(!$Orchestrator_CAs_to_Test)
                    {
                        Write-Host -ForegroundColor Yellow "`nPlease provide the Certificate Authorities to test connectivity to.`nCA Hostname (FQDN) or <CA Hostname>/<CA Logical Name> are acceptable values.`n"
                        $Orchestrator_CAs_to_Test = @()
                        $CA_continue = $true
                        $CA_count = 1
                        while($CA_continue -eq $true)
                        {
                            # Prompt for a CA entry
                            Write-Host 'Add a CA or enter "Done" to continue.'
                            $ca_to_test = Read-Host -Prompt "Certificate Authority $CA_count"
                            IF($ca_to_test -ieq "Done")
                            {
                                $CA_continue = $false
                            }
                            ELSE
                            {
                                # If FQDN
                                IF($ca_to_test -like "*.*")
                                {                            
                                    $Orchestrator_CAs_to_Test += $ca_to_test
                                    Write-Host -ForegroundColor Green "Added!"
                                    $CA_count++
                                }
                                ELSE
                                {
                                    Write-Host -ForegroundColor Red 'CA not added. Please ensure the CA hostname is the Fully Qualified Domain Name (e.g "servername.domain.com")'
                                }
                            }
                        } # End While
                    }
                } 
            } # End CA connectivity
            #region Determine service account
            IF(!$Orchestrator_ServiceAccount)
            {
                # Prompt Y/N for default option
                Write-Host -ForegroundColor Yellow "`nThe Keyfactor Orchestrator service can run on this server as one of the following:"
                write-host -ForegroundColor Yellow "`t - NT AUTHORITY\NETWORK SERVICE  (default)"
                write-host -ForegroundColor Yellow "`t - Domain Account"
                write-host -ForegroundColor Yellow "`t - Group Managed Service Account (gMSA)"
                Write-Host -ForegroundColor yellow "`t Note: Keyfactor personell do not advise or support the creation of gMSAs within your Active Directory."

                $Orchestrator_ServiceAccount_Prompt = Read-Host -Prompt "`nWill the service use the default account of NT AUTHORITY\NETWORK SERVICE? (Y/N)"

                IF($Orchestrator_ServiceAccount_Prompt -inotlike "*y*")
                {
                    while(!$Orchestrator_ServiceAccount -and ($Orchestrator_ServiceAccount -notlike "*@*" -or $Orchestrator_ServiceAccount -notlike "*$"))
                    {
                        $Orchestrator_ServiceAccount = Read-Host -Prompt "Enter the UPN (<username>@<domain>) of the account that will run the service"
                    }
                }
            }

        }
    }
    ELSE{
        Write-Host -ForegroundColor Red "An invalid value was provided."
    }
}

# Exit if no validation types were provided
IF(!$Validate_Orchestrator -and !$Validate_CloudGateway)
{
    Write-Host -ForegroundColor Red "A validation type must be provided."
    Write-Host -ForegroundColor Red 'Please uncomment one of the validation type variables at the top of the script OR choose a valid option.'
    throw "Exiting"
}

# If the variable doesn't exist, prompt for it.
IF(!$Keyfactor_Command_Domain)
{
    $Keyfactor_Command_Domain = Read-Host -Prompt "`nPlease enter the domain name of your Keyfactor Command environment (https://<Keyfactor Command URL>/)"

    # Validate the provided value
    IF($Keyfactor_Command_Domain -like "https://*")
    {
        $Keyfactor_Command_Domain = $Keyfactor_Command_Domain.Replace("https://","")
    }
    $keyfactor_Command_parent_Domain = ($Keyfactor_Command_Domain.Split(".")[1])
}

# Declare result hash table
$hashtable = @{}

# Cloud Enrollment Gateway Validation #
IF($Validate_CloudGateway -eq $true)
{
    Write-Host -ForegroundColor Black -BackgroundColor Yellow "`n######## Cloud Gateway Prerequisite Validation ##########"
    # Validate OS version
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nConfirming this OS version is supported by the Cloud Gateway"
    $OS_Supported = Confirm-OSMinimumVersion -Supported_OS $CEGW_Supported_OS
    $hashtable.Add("Cloud Gateway - Supported OS",$OS_Supported)

    # .NET Validation
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking for .NET Framework installation."
    $cegw_dotNet_status = Confirm-DotNetFramework -MinVersion $CEGW_dotNetFW_MinVersion
    $hashtable.Add("Cloud Gateway - dotNet Installed",$cegw_dotNet_status)

    # Keyfactor Command Connectivity
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nTesting connectivity to Keyfactor"
    $keyfactor_command_connection = Test-KeyfactorConnection -url ("https://" + $Keyfactor_Command_Domain + "/keyfactor") -parent_domain $keyfactor_Command_parent_Domain
    $hashtable.Add("Keyfactor Command Connection",$keyfactor_command_connection)

    # Entrust CRL
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nTesting connectivity to Entrust CRL"
    $entrust_crl_connection = Test-EntrustCRL
    $hashtable.Add("Entrust CRL Connection",$entrust_crl_connection)    

    # Check for Proxy if Keyfactor Command test failed
    IF($keyfactor_command_connection -ne $true){
        Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking if a proxy is configured."
        $proxy_configured = Confirm-Proxy
        IF($proxy_configured -eq $false)
        {
            $hashtable.Add("Cloud Gateway - Proxy Configured","Review")        
        }
        ELSEIF($proxy_configured -eq $true)
        {
            $hashtable.Add("Cloud Gateway - Proxy Configured",$proxy_configured)
        }        
    }

    # Check for DCOM/RPC inbound, if the CEGW will run the Keyfactor Gateway service
    IF($CEGW_SyncOnly -eq $false)
    {
        Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking local firewall rules for RPC/DCOM"
        # RPC
        $RPC_Inbound = (Confirm-InboundPort-Allowed -LocalPort 135 -RemotePort Any)
        $hashtable.Add("Cloud Gateway - Allowed inbound RPC",$RPC_Inbound[0])
        $DCOM_Inbound = (Confirm-InboundPort-Allowed -LocalPort RPC -RemotePort 50000) # Check for a port in the middle of the default DCOM range (49152-65535)
        $hashtable.Add("Cloud Gateway - Allowed inbound DCOM",$DCOM_Inbound[0])
    }
    # User Logon As Service
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking service account for Logon-As-Service permission"
    IF($CEGW_ServiceAccount)
    {
        $logon_as_service = (Confirm-UserLogonAsService -UPN $CEGW_ServiceAccount)
        $hashtable.Add("Cloud Gateway - Logon-As-Service - ($CEGW_ServiceAccount)",$logon_as_service)
    }

    # Active Directory PowerShell module
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking for Active Directory PowerShell Module"
    $hashtable.Add("Cloud Gateway - Active Directory PowerShell Module",(Confirm-ADPSModule))

    # Active Directory Web Services
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nTesting connectivity to Active Directory Web Services"
    $adws_connection = (Test-OutboundPort -Target (Get-WmiObject -Class Win32_ComputerSystem).domain -Port 9389)
    $hashtable.Add("Cloud Gateway - ADWS Connection",$adws_connection)

    #region Certificate Templates (AD)
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nTesting permissions to AD Certificate Templates"
    $template_names = (Get-ADCertificateTemplates | Select-Object -Last $CEGW_templateAccess_limit)
    $template_count = $template_names.count
    IF($template_count -gt 0)
    {
        $hashtable.Add(("Cloud Gateway - Template Read Permission (Returned $template_count templates)"),$true)
    }ELSE{
        $hashtable.Add(("Cloud Gateway - Template Read Permission (Returned $template_count templates)"),$false)
    }
    #endregion     
}

# Universal Orchestrator Validation #
IF($Validate_Orchestrator -eq $true)
{
    Write-Host -ForegroundColor Black -BackgroundColor Yellow "`n######## Orchestrator Prerequisite Validation ##########"
    # Validate OS version
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nConfirming this OS version is supported by the Universal Orchestrator"
    $OS_Supported = Confirm-OSMinimumVersion -Supported_OS $Orchestrator_Supported_OS
    $hashtable.Add("Orchestrator - Supported OS",$OS_Supported)

    # .NET Validation
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking for .NET Core installation."
    $orchestator_dotNet_status = Confirm-DotNetRuntime -Runtime "Microsoft.NETCore.App" -MinVersion $Orchestrator_dotNetCore_MinVersion
    $hashtable.Add("Orchestrator - dotNet Installed",$orchestator_dotNet_status)

    # Keyfactor Command Connectivity
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nTesting connectivity to Keyfactor"
    $keyfactor_command_connection = Test-KeyfactorConnection -url ("https://" + $Keyfactor_Command_Domain + "/keyfactor") -parent_domain $keyfactor_Command_parent_Domain
    try
    {
        $hashtable.Add("Keyfactor Command Connection",$keyfactor_command_connection)
    }Catch{}

    # Entrust CRL
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nTesting connectivity to Entrust CRL"
    $entrust_crl_connection = Test-EntrustCRL
    try
    {
        $hashtable.Add("Entrust CRL Connection",$entrust_crl_connection)
    }Catch{}

    # Check for Proxy if Keyfactor Command test failed
    IF($keyfactor_command_connection -ne $true){
        Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking if a proxy is configured."
        $proxy_configured = Confirm-Proxy
        IF($proxy_configured -eq $false)
        {
            $hashtable.Add("Orchestrator - Proxy Configured","Review")        
        }
        ELSEIF($proxy_configured -eq $true)
        {
            $hashtable.Add("Orchestrator - Proxy Configured",$proxy_configured)
        }        
    }

    # Check CA connection
    IF($Orchestrator_CheckCAConnectivity -eq $true)
    {   
        # Check each CA that was defined in this script   
        foreach($CA_string in $Orchestrator_CAs_to_Test){
            Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking CA connectivity for CA:"
            $CA_connectivity = $null
            $CA_connectivity = Test-CAConnection -CA $CA_string
            $hashtable.Add("Orchestrator - CA Connection ($CA_String)",$CA_connectivity)
        }
    }

    # User Logon As Service
    Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nChecking service account for Logon-As-Service permission"
    IF($Orchestrator_ServiceAccount)
    {
        $logon_as_service = (Confirm-UserLogonAsService -UPN $Orchestrator_ServiceAccount)
        $hashtable.Add("Orchestrator - Logon-As-Service - ($Orchestrator_ServiceAccount)",$logon_as_service)
    }
}

# Print the test results
Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nPrinting validation results`n"
Write-ValidationResults -hashtable $hashtable

# Print helper text
IF($hashtable.Values -contains $false)
{
    start-sleep -Seconds 3
    # Keyfactor Command Connection
    IF($hashtable["Keyfactor Command Connection"] -eq $false)
    {
        Write-Host -ForegroundColor Yellow "`nHelper Text for Keyfactor Command Connection Failure"
        Write-Host $Helper_KeyfactorConnection
    }
    # CEGW AD PowerShell MOdule
    IF($hashtable["Cloud Gateway - Active Directory PowerShell Module"] -eq $false)
    {
        Write-Host -ForegroundColor Yellow "`nHelper Text for Active Directory PowerShell Module"
        Write-Host $Helper_ADModule
    }
    # Entrust CRL Connection
    IF($hashtable["Entrust CRL Connection"] -eq $false)
    {
        Write-Host -ForegroundColor Yellow "`nHelper Text for Entrust CRL Connection"
        Write-Host $Helper_Entrust_CRL
    }
    # Cloud Gateway - RPC/DCOM Firewall Rules
    foreach($rule in $hashtable.Keys.Where({$_ -like "Cloud Gateway - Allowed Inbound*"}))
    {
        IF($hashtable[$rule] -eq $false)
        {
            Write-Host -ForegroundColor Yellow "`nHelper Text for RPC/DCOM failure"
            Write-Host $Helper_RPC_DCOM
            continue
        }
    }
    # Cloud Gateway - dotNet Installed
    IF($hashtable["Cloud Gateway - dotNet Installed"] -eq $false)
    {
        Write-Host -ForegroundColor Yellow "`nHelper Text for dotNet Framework failure"
        Write-Host $Helper_DotNetFramework
    }
    # Cloud Gateway - Active Directory Web Services
    IF($hashtable["Cloud Gateway - ADWS Connection"] -eq $false)
    {
        Write-Host -ForegroundColor Yellow "`nHelper Text for ADWS Connection Failure"
        Write-Host $Helper_ADWS_Connection
    }
    # Orchestrator .NET Core
    IF($hashtable["Orchestrator - dotNet Installed"] -eq $false)
    {
        Write-Host -ForegroundColor Yellow "`nHelper Text for .NET Core failure"
        Write-Host $Helper_DotNetCore
    }
    # Orchestrator - CA Connectivity
    foreach($CA in $hashtable.Keys.Where({$_ -like "Orchestrator - CA Connection*"}))
    {
        IF($hashtable[$CA] -eq $false)
        {
            Write-Host -ForegroundColor Yellow "`nHelper Text for CA Connectivity failure"
            Write-Host $Helper_CAConnectivity
            continue
        }
    }
    # Logon As Service
    foreach($Account in $hashtable.Keys.Where({$_ -like "Logon-As-Service*"}))
    {
        IF($hashtable[$Account] -eq $false)
        {
            Write-Host -ForegroundColor Yellow "`nHelper Text for Logon-As-A-Service permission"
            Write-Host $Helper_LogonAsService
            continue
        }
    }
}

# Determine result file location
IF(!$validation_result_path)
{
    # Determine location this script is being executed from
    # Name of this script
    IF($MyInvocation.MyCommand.Name)
    {                     
        $script_name = $MyInvocation.MyCommand.Name
    }
    ELSE
    {
        $script_name = (($psISE.CurrentFile.DisplayName).TrimEnd("*"))
    }

    # Path of the script
    IF($PSScriptRoot)
    {                                    
        $script_path = $PSScriptRoot
    }
    ELSE
    {
        # If this script is not being executed from a PowerShell window, assume ISE.                                                
        $script_path = $psISE.CurrentFile.FullPath
        $script_path = $script_path.Replace($script_name,"")
    }
    $validation_result_path = ($script_path+"KF_Validation_Result_"+(Get-Date -Format "yyyyMMdd")+".txt")
}

# Write validation result file
Out-File -FilePath $validation_result_path -InputObject ("Results for validation performed on "+(Get-Date))
foreach($i in $hashtable.keys){
    $line = ('"'+$i+'","'+$hashtable[$i]+'"')
    Out-File -FilePath $validation_result_path -InputObject $line -Append
}

Write-Host -ForegroundColor Cyan -BackgroundColor Black "`nSaved result file:"
Write-Host $validation_result_path

# Clear values
$Keyfactor_Command_Domain = $null
$hashtable = $null
$Validate_Orchestrator = $Null
$Validate_CloudGateway = $Null
$Orchestrator_CheckCAConnectivity = $null
$Orchestrator_CAs_to_Test = $null
$CEGW_SyncOnly = $null
$CEGW_ServiceAccount = $null
$CEGW_Sync_Prompt = $null
$CEGW_ServiceAccount_Prompt = $null
$Orchestrator_ServiceAccount = $null
$Orchestrator_ServiceAccount_Prompt = $null

# END SCRIPT
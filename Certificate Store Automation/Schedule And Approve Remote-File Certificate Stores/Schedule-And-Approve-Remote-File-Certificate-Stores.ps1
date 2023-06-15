<#
.NOTES
    Created on:   	6/9/2023
    Created by:   	Keyfactor
    Filename: Schedule-And-Approve-Remote-File-Certificate-Stores.ps1
    Tested on Keyfactor Command v10.3

.DESCRIPTION
    
    This script allows Keyfactor administrators to discover and approve Certificate Stores within Keyfactor, on a mass scale.
    Multiple executions of this script are required to complete the discovery and approval phases of this process.
    After each execution, the user will add additional information to newly created files that this script creates, which will be used in the next step.

    The different phases of this script are below:

    1. [Script]  Create a "Machine Details" file.
    2. [User]    Populate server details in the "Machine Details" file.
    2. [Script]  Create Discovery jobs to discover certificate stores on machines provided in the machine details file.
    3. [Script]  Export newly discovered Certificate Stores to a "Pending Cert Stores" file.
    4. [User]    Populate certificate store details in the "Pending Cert Stores" file.
    5. [Script]  Approve pending Certificate Stores using details in the pending cert stores file.

    This script is currently only applicable for the following certificate store types:

    1. Remote File - JKS (RFJKS)
    2. Remote File - PEM (RFPEM)
    3. Remote File - PKCS12 (RFPKCS12)

    Please refer to the GitHub README page of this script for additional information.

.PARAMETERS

    The following variables are present in the script:

    MANDATORY Edit Required
    1. Username   -   Username of the Keyfactor API Account
    2. Password   -   Password of the Keyfactor API Account
    3. ApiURL     -   API URL of the Keyfactor environment

    OPTIONAL Edit Possible
    1. Machine_Details              -   The filepath of the Machine Details file created by this script upon 1st execution.
    2. Pending_CertStores_Dir       -   The directory where Pending Certificate Stores will be exported.
    3. Pending_CertStores_FileName  -   The filename of the Pending Certificate Stores file.
    4. Log_Dir                      -   The directory where log files will be created.
    5. Log_FileName                 -   The filename of the log.
    6. Log_Trace                    -   Whether to include verbose info of submitted API calls to the log.
    

.OUTPUT

    In addition to console output, this script creates the following files:

    1. Machine Details  -  A file used to create Keyfactor Discovery jobs.
    2. Pending Certificates  -  A file used to add required info while approving newly discovered Keyfactor Certificate Stores.
    3. Log  -  A detailed log file that can be used to track this processes actions/results.

#>


##############################################
#  API INFO for your Keyfactor Environment   #
##############################################

# MUST be updated for your Keyfactor environment.

$Username = '<domain>\<API_User_Name>'
$Password = '<API_User_Secure_Password>'
$Apiurl   = 'https://<domain>.keyfactorAPI.com/KeyfactorAPI/'


##########################
#  Machine Details File  #
##########################

#  File used to schedule Keyfactor Discovery Jobs
#  and later approve discovered certificate stores.
#
#  1. Required to schedule Discovery Jobs
#  2. Optionally used to provide machine credentials
#     when approving certificate stores.

$Machine_Details = "C:\temp\Machine_Details.csv"

#####################################
#  Pending Certificate Stores File  #
#####################################

#  Directory and File to export pending certificate stores.
#  
#  1. This file can be exported at the 3rd prompt of this script
#  and contains a list of found pending certificate stores.
#  
#  2. This file is also used to approve certificate stores,
#     by editing it and providing certificate store data.
#
#  Note: Providing machine credential information in this file,
#        prior to approving certificate stores, is optional. If the
#        "machine details" file used to discover certificate stores is
#        still available to this script, it will be used to identify
#        the credential for a given machine.
#        If the "pending certificates" file has a machine credential for
#        a given machine, then it takes priority.

$Pending_CertStores_Dir = "C:\temp"
$Pending_CertStores_FileName = ("Keyfactor_Pending_CertStores")

##############
#  Log File  #
##############

#  Note: This script attempts to redact passwords from logged events when trace is enabled,
#        however, more detailed events might still expose a credential.
#        Review log files before moving them to another location.
#

$Log_Dir = ("C:\temp")
$Log_FileName = ("Keyfactor_Log")
$Log_Trace = $false


###############
#  FUNCTIONS  #
###############

function Write-KFLog{

    param(
        [Parameter(Mandatory,HelpMessage='Log Message')]
            [string]$Message,
        [Parameter(HelpMessage='Log Message')]
            [array]$Artifact
    )
    
    IF($Artifact){
        IF($Artifact.GetType().Name -ne "String"){

            # Redact potential password values
            try{
                IF((Get-Member -InputObject $Artifact).Name -match "ServerPassword"){
                    $Artifact.ServerPassword = "<Redacted>"
                }
            }Catch{}

            try{
                IF($Artifact.ServerPassword){
                    $Artifact.ServerPassword = "<Redacted>"
                }
            }Catch{}

            # Convert the object to json/string
            $Artifact_string = ($Artifact | ConvertTo-Json -Depth 100 -Compress)
            $Artifact_string = $Artifact_string.ToString()
            $Artifact = $Artifact_string.replace('"',"")

        }ELSE{
            $Artifact_json = $Artifact | ConvertTo-Json -Depth 100 -Compress
            try{
                IF($Artifact_json.ServerPassword){
                    $Artifact_json.ServerPassword = "<Redacted>"
                }
                $Artifact_string = $Artifact_string.ToString()
                $Artifact = $Artifact_string.replace('"',"")
            }Catch{}
        }

            # Create log entry with artifact
            $log_entry = ('"'+(Get-Date -Format "MM/dd/yyyy hh:mm:ss")+'","'+$Message+'","'+$Artifact+'"')

    }ELSE{
        $log_entry = ('"'+(Get-Date -Format "MM/dd/yyyy hh:mm:ss")+'","'+$Message+'"')
    }

    # Add to log file
    try{
        Out-File -FilePath $log_fullname -InputObject $log_entry -Encoding ascii -Append
    }Catch{
        throw $_
    }
}

# Function to connect to API
function Connect-KFAPI{

    # Confirm variables exist
    IF(!$username -or !$password){
        return "Credentials variables are missing"
    }

    # Ensure apiurl doesn't have a trailing slash
    IF($apiurl.EndsWith("/"))
    {
        $apiurl = $apiurl.TrimEnd("/")
    }
    

    # Reset any variables that may already exist
    $pair = $null
    $script:base64AuthInfo = $null
    $credential = $null
    $API_Session = $null

    # Confirm which Submit-KFAPI function is used (basic/PowerShell Cred)
    IF(Get-Command Submit-KFAPI | where {$_.ScriptBlock -like '*("Authorization", "Basic $script:base64AuthInfo")*'}){
            
        #auth encoding
        $pair = "$($script:username):$($script:Password)"
        $script:base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

        # Test headers
        $testheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $testheaders.Add('content-type', 'application/json')
        $testheaders.Add("X-Keyfactor-Requested-With", "APIClient")
        $testheaders.Add("Authorization", "Basic $script:base64AuthInfo")

        # Authenticate to Keyfactor API
        try{
            $KF_connect = (Invoke-RestMethod -Uri ($apiurl+"/Status/EndPoints") -Headers $testheaders)
        }Catch{
            throw "Couldn't authenticate with basic authentication."
        }
    }ELSE{        
            
        # Build credential
        $secure_password = $script:password | ConvertTo-SecureString -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($script:username,$secure_password)
        $script:API_Session = New-Object -TypeName Microsoft.PowerShell.Commands.WebRequestSession -Property @{Credentials=$credential}

        # Authenticate to Keyfactor API
        # Authenticate to Keyfactor API
        try{
            $KF_connect = (Invoke-RestMethod -Uri ($apiurl+"Status/EndPoints") -WebSession $script:API_Session)
        }Catch{
            throw "Couldn't authenticate with PScredential authentication."
        }
        write-host "PowerShell credential used"
    }
}

# Sumbit KF API Call (Basic Auth)
function Submit-KFAPI{
    param(

    [Parameter(Mandatory,HelpMessage='Parent URL for KeyfactorAPI')]
        [string]$KeyfactorAPI_URL,
    [Parameter(Mandatory,HelpMessage='Name of Keyfactor role')]
        [string]$API_Call,
    [Parameter(HelpMessage='Body of request')]
        [string]$Body,
    [Parameter(Mandatory,HelpMessage='Method of API call')]
    [ValidateSet(“GET”,”POST”,"PUT","DELETE")]
        [string]$Method

    )

    # If the required auth variable doesn't exist, attempt connecting to create it
    IF(!$script:base64AuthInfo){
        Connect-KFAPI
    }

    # Build FUll URL and ensure double slashes don't exist
    IF($API_Call.StartsWith("/"))
    {
        $API_Call = $API_Call.TrimStart("/")
    }
    IF($apiurl.EndsWith("/"))
    {
        $apiurl = $apiurl.TrimEnd("/")
    }
    
    # Build the full URI
    $URI = ($KeyfactorAPI_URL+"/"+$API_Call)
    
    # Build headers
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add('content-type', 'application/json')
    $headers.Add("X-Keyfactor-Requested-With", "APIClient")
    $headers.Add("Authorization", "Basic $script:base64AuthInfo")

    IF(!$Body){
        $updateResponse = Invoke-RestMethod -Method $Method -Uri $URI -Headers $headers
    }ELSE{
        $updateResponse = Invoke-RestMethod -Method $Method -Uri $URI -Body $Body -Headers $headers
    }
    return $updateResponse
}

# Function to retrieve Keyfactor Orchestrator(s)
function Get-KF-Orchestrator{
    param(
    [Parameter(HelpMessage='Optional: Get a single Orchestrator by name')]
        [string]$Name,
    [Parameter(HelpMessage='Only return the ID of a single orchestrator. Only applicable when Name is defined')]
        [switch]$ReturnID
    )

    # Throw a warning if returnID was defined without a Name
    IF($ReturnID -and !$Name){
        Write-Warning -Message "ReturnID is only applicale if an orchestrator name is also provided."
    }
    
    # If name was defined, specify a query string
    IF($Name){
        $agent = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call ("Agents?pq.queryString=ClientMachine%20-eq%20%22"+$Name+"%22") -Method Get)          
        
        # If return ID was defined
        IF($ReturnID){
            return $agent.AgentId
        }ELSE{
            return $agent
        }
    }ELSE{
        return (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "Agents" -Method Get)
    }   
}

# Function to retrieve certificate stores
function Get-KF-CerificateStores{
    
    param(
        [Parameter(HelpMessage='Return certificate stores belonging to a container')]
            [string]$ContainerID,        
        [Parameter(HelpMessage='Return certificate stores of a specific type')]
            [string]$CertStoreTypeID,
        [Parameter(HelpMessage='Return pending certificate stores')]
            [switch]$ReturnPending
    )
    
    # Define an array for query options
    $querystring = @("CertStoreType%20-ne%20null")
                      
    IF($ContainerID){
        $querystring += ("ContainerId%20-eq%20%22"+$ContainerId+"%22")
    }
    IF($CertStoreTypeID){
        $querystring += ("CertStoreType%20-eq%20"+$CertStoreTypeID)
    }
    IF($ReturnPending.IsPresent){
        $querystring += ("Approved%20-eq%20%22false%22")
    }
                      
    $querystring = $querystring -join "%20AND%20"

    # Define array and paging limits
    $cert_stores = @()
    $query_page = 1
    $query_limit = 25
    
    # Initial query
    $cert_stores_query = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores?certificateStoreQuery.queryString=$querystring&pageReturned=$query_page&certificateStoreQuery.returnLimit=$query_limit" -Method Get)
    
    # Add initial results to master array   
    IF($cert_stores_query){
        $cert_stores += $cert_stores_query
    }Else{
        return
    }
   
    # Loop pages to retrieve all certificate stores
    while($cert_stores_query){
        
        # Print
        Write-Host -ForegroundColor Green "Retrieved page $query_page"

        # Reset the query result and increment the page
        $cert_stores_query = $null
        $query_page++

        # Query again and add to the array
        $cert_stores_query = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores?certificateStoreQuery.pageReturned=$query_page&certificateStoreQuery.returnLimit=$query_limit" -Method Get)
        $cert_stores += $cert_stores_query

    }

    return $cert_stores

}

# Function to schedule certificate store discovery
function New-KF-DiscoveryJob{

    param(
        [Parameter(HelpMessage='Keyfactor agent ID')]
            [string]$OrchestratorID,
        [Parameter(HelpMessage='Keyfactor Certificate Store Type Name')]
            [string]$CertStoreTypeShortName,         
        [Parameter(HelpMessage='Client Machine')]
            [string]$MachineName,
        [Parameter(HelpMessage='UseSSL')]
            [string]$UseSSL,
        [Parameter(HelpMessage='Server username')]
            [string]$ServerUsername,
        [Parameter(HelpMessage='Server password')]
            [string]$ServerPassword,
        [Parameter(HelpMessage='Dirs to scan')]
            [string]$directoriesToScan,
        [Parameter(HelpMessage='Dirs to ignore')]
            [string]$directoriesToIgnore,
        [Parameter(HelpMessage='File extension to include')]
            [string]$FileExtension,
        [Parameter(HelpMessage='Filename pattern to match')]
            [string]$FilePatternToMatch,
        [Parameter(HelpMessage='Include PKCS12 Files')]
            [string]$IncludePKCS12,
        [Parameter(HelpMessage='Server password')]
            [string]$FollowSymLinks
    )

    # Default non-provided fields to false
    IF(!$UseSSL){
        $UseSSL = $false
    }
    IF(!$IncludePKCS12){
        $IncludePKCS12 = $false
    }
    IF(!$FollowSymLinks){
        $FollowSymLinks = $false
    }

    # Set machine name syntax
    IF($UseSSL -eq $true -or $UseSSL -eq "true"){
        write-host "Using HTTPS syntax for machine name"
        $MachineName = ("https://"+$machineName+":5986")
    }
    IF($UseSSL -eq $false -or $UseSSL -eq "false"){
        write-host "UseSSL not set. Defaulting to HTTP syntax for machine name"
        $MachineName = ("http://"+$machineName+":5985")
    }
    
    # Create hashtable
    $body = @{"AgentId"=$OrchestratorID}
    $body.Add("ClientMachine",$MachineName)
    $body.Add("Compatibility",$IncludePKCS12)
    $body.Add("Extensions",$FileExtension)
    $body.Add("Dirs",$directoriesToScan)
    $body.Add("IgnoredDirs",$directoriesToIgnore)
    $body.Add("JobExecutionTimestamp",((Get-Date).AddMinutes(1).ToUniversalTime().ToString('u')))
    $body.Add("KeyfactorSchedule",@{"Immediate"=$true})
    $body.Add("NamePatterns",($FilePatternToMatch))
    $body.Add("ServerUsername",@{"SecretValue"=$ServerUsername})
    $body.Add("ServerPassword",@{"SecretValue"=$ServerPassword})
    $body.Add("ServerUseSsl",$UseSSL)
    $body.Add("SymLinks",$FollowSymLinks)
 
    # Determine Certstore ID Number
    $CertStoreTypeID = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStoreTypes/Name/$CertStoreTypeShortName" -Method Get).StoreType
    
    # Add ID number
    $body.Add("Type","$CertStoreTypeID")
    
    # Capture body for log
    $log_body = $body

    # Convert store pass to JSON string
    $body = (($body | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    
    # Log if trace is enabled
    IF($log_trace -eq $true){
   
        try{$log_body.Password = "<Redacted>"}Catch{}
        try{$log_body.ServerPassword = "<Redacted>"}Catch{}
        Write-KFLog -Message "CertStore_Approve_Submit" -Artifact $log_body

    }

    return (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores/DiscoveryJob" -Body $body -Method Put)

}

# Function to retrieve scheduled discovery jobs
function Get-KF-DiscoveryJobs{
    param(
            [Parameter(HelpMessage='Keyfactor agent ID')]
            [string]$OrchestratorID
    )
    
    # If an Orchestrator ID was provided, query specific discovery jobs for it. Otherwise, return all.
    IF($OrchestratorID){

        $discovery_jobs = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call ("OrchestratorJobs/ScheduledJobs?pq.queryString=AgentID%20-eq%20%22"+$OrchestratorID+"%22%20AND%20JobType%20-contains%20%22Discovery%22%20AND%20JobType%20-notcontains%20%22SslDiscovery%22") -Method Get)
        return ($discovery_jobs | select JobType,@{Name='Orchestrator';Expression={$_.ClientMachine}},Requested)

    }ELSE{

        $discovery_jobs = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call ("OrchestratorJobs/ScheduledJobs?pq.queryString=JobType%20-contains%20%22Discovery%22%20AND%20JobType%20-notcontains%20%22SslDiscovery%22") -Method Get)
        return ($discovery_jobs | select JobType,@{Name='Orchestrator';Expression={$_.ClientMachine}},Requested)

    }        
}

# Function to approve certificate store
function Approve-KF-CertificateStore-PEM{
 param(
        [Parameter(Mandatory,HelpMessage='Certificate store ID')]
            [string]$CertStoreID,        
        [Parameter(Mandatory,HelpMessage='Certificate store type ID')]
            [string]$CertStoreTypeID,
        [Parameter(HelpMessage='Return pending certificate stores')]
            [string]$ContainerID,
        [Parameter(HelpMessage='Store password of the cert store')]
            [string]$StorePassword,
        [Parameter(Mandatory,HelpMessage='Server username')]
            [string]$ServerUserName,
        [Parameter(Mandatory,HelpMessage='Server password')]
            [string]$ServerPassword,
        [Parameter(HelpMessage='Use SSL')]
            [string]$UseSSL,
        [Parameter(HelpMessage='Switch (boolean) for if store contains chain')]
            [string]$IncludesChain,
        [Parameter(HelpMessage='Switch (boolean) for if store is trust store')]
            [string]$IsTrustStore,
        [Parameter(HelpMessage='Switch (boolean) for if store is RSA PrivateKey')]
            [string]$IsRSAPrivateKey,
        [Parameter(HelpMessage='If the store has a separate private key file')]
            [string]$SeparatePrivateKeyFile,
        [Parameter(HelpMessage='Default file permission to use on Linux Server')]
            [string]$LinuxFilePermissionOnCreate,
        [Parameter(HelpMessage='Default file owner to use on Linux Server')]
            [string]$LinuxFileOwnerOnCreate
    )

    # Set values not provided to False
    IF(!$UseSSL){
        $UseSSL = $false
    }

    IF(!$IsTrustStore){
        $IsTrustStore = $false
    }
    IF(!$IncludesChain){
        $IncludesChain = $false
    }
    IF(!$IsRSAPrivateKey){
        $IsRSAPrivateKey = $false
    }

    # Set container ID to null if one wasn't provided.
    IF(!$ContainerID){
        $ContainerID = '""'
    }ELSE{
        $ContainerID = [int]$ContainerID
    }

    IF(!$SeparatePrivateKeyFile){
        $SeparatePrivateKeyFile = ''
    }
    IF(!$LinuxFilePermissionOnCreate){
        $LinuxFilePermissionOnCreate = ''
    }
    IF(!$LinuxFileOwnerOnCreate){
        $LinuxFileOwnerOnCreate = ''
    }

    ## Secret Values ##
    # Ensure double backslash is included in username & SeparateKeyFilePath
    IF($ServerUserName -like "*\*" -and $ServerUserName -notlike "*\\*"){
        $ServerUserName = $ServerUserName.Replace("\","\\")
    }
    IF($SeparatePrivateKeyFile -like "*\*" -and $SeparatePrivateKeyFile -notlike "*\\*"){
        $SeparatePrivateKeyFile = $SeparatePrivateKeyFile.Replace("\","\\")
    }
    $username_secret = @{"SecretValue"=$ServerUsername}
    $username_value = @{"value"=$username_secret}
    $password_secret = @{"SecretValue"=$ServerPassword}
    $password_value = @{"value"=$password_secret}
   
    # Store pass
    IF(!$StorePassword){
        $storepass_secret = @{"SecretValue"=$null}
        $storepass_string = (($storepass_secret | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    }ELSE{
        $storepass_secret = @{"SecretValue"=$StorePassword}
        $storepass_string = (($storepass_secret | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    }
       
    # Create hashtable
    $property = @{"ServerUsername"=$username_value}
    $property.Add("ServerPassword",$password_value)
    $property.Add("ServerUseSsl",$UseSSL)
    $property.Add("IsTrustStore",@{"value"=$IsTrustStore})
    $property.Add("IsRSAPrivateKey",@{"value"=$IsRSAPrivateKey})
    $property.Add("IncludesChain",@{"value"=$IncludesChain})
    $property.Add("SeparatePrivateKeyFilePath",@{"value"=$SeparatePrivateKeyFile})
    $property.Add("LinuxFilePermissionsOnStoreCreation",@{"value"=$LinuxFilePermissionOnCreate})
    $property.Add("LinuxFileOwnerOnStoreCreation",@{"value"=$LinuxFileOwnerOnCreate})
    
    # Convert store pass to JSON string
    $property_string = (($property | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    $property_string = $property_string.Replace('"','\"')

    # Build final body
    $body = "[{
      `"ContainerId`" `: `"$CertStoreContainerID`",
      `"CertStoreType`": $CertStoreTypeID,
      `"Password`": $storepass_string,
      `"Properties`": `"$property_string`",
      `"Id`" `: `"$CertStoreID`"
    }]"
    
    # Log if trace is enabled
    IF($log_trace -eq $true){
        $log_body = $body
        try{$log_body.Password = "<Redacted>"}Catch{}
        try{$log_body.Properties.ServerPassword = "<Redacted>"}Catch{}
        Write-KFLog -Message "CertStore_Approve_Submit" -Artifact $log_body
    }

    return (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores/Approve" -Body $body -Method POST)

}

# Function to approve certificate store
function Approve-KF-CertificateStore-JKS{
 param(
        [Parameter(Mandatory,HelpMessage='Certificate store ID')]
            [string]$CertStoreID,        
        [Parameter(Mandatory,HelpMessage='Certificate store type ID')]
            [string]$CertStoreTypeID,
        [Parameter(HelpMessage='Return pending certificate stores')]
            [string]$ContainerID,
        [Parameter(HelpMessage='Store password of the cert store')]
            [string]$StorePassword,
        [Parameter(Mandatory,HelpMessage='Server username')]
            [string]$ServerUserName,
        [Parameter(Mandatory,HelpMessage='Server password')]
            [string]$ServerPassword,
        [Parameter(HelpMessage='Use SSL')]
            [string]$UseSSL,
        [Parameter(HelpMessage='Default file permission to use on Linux Server')]
            [string]$LinuxFilePermissionOnCreate,
        [Parameter(HelpMessage='Default file owner to use on Linux Server')]
            [string]$LinuxFileOwnerOnCreate
    )

    # Set values not provided to False
    IF(!$UseSSL){
        $UseSSL = $false
    }

    # Set container ID to null if one wasn't provided.
    IF(!$ContainerID){
        $ContainerID = '""'
    }ELSE{
        $ContainerID = [int]$ContainerID
    }

    IF(!$LinuxFilePermissionOnCreate){
        $LinuxFilePermissionOnCreate = ''
    }
    IF(!$LinuxFileOwnerOnCreate){
        $LinuxFileOwnerOnCreate = ''
    }

    ## Secret Values ##
    # Ensure double backslash is included in username
    IF($ServerUserName -like "*\*" -and $ServerUserName -notlike "*\\*"){
        $ServerUserName = $ServerUserName.Replace("\","\\")
    }
    $username_secret = @{"SecretValue"=$ServerUsername}
    $username_value = @{"value"=$username_secret}
    $password_secret = @{"SecretValue"=$ServerPassword}
    $password_value = @{"value"=$password_secret}
   
    # Store pass
    IF(!$StorePassword){
        $storepass_secret = @{"SecretValue"=$null}
        $storepass_string = (($storepass_secret | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    }ELSE{
        $storepass_secret = @{"SecretValue"=$StorePassword}
        $storepass_string = (($storepass_secret | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    }
       
    # Create hashtable
    $property = @{"ServerUsername"=$username_value}
    $property.Add("ServerPassword",$password_value)
    $property.Add("ServerUseSsl",$UseSSL)
    $property.Add("LinuxFilePermissionsOnStoreCreation",@{"value"=$LinuxFilePermissionOnCreate})
    $property.Add("LinuxFileOwnerOnStoreCreation",@{"value"=$LinuxFileOwnerOnCreate})
    
    # Convert store pass to JSON string
    $property_string = (($property | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    $property_string = $property_string.Replace('"','\"')

    # Build final body
    $body = "[{
      `"ContainerId`" `: `"$CertStoreContainerID`",
      `"CertStoreType`": $CertStoreTypeID,
      `"Password`": $storepass_string,
      `"Properties`": `"$property_string`",
      `"Id`" `: `"$CertStoreID`"
    }]"
    
    # Log if trace is enabled
    IF($log_trace -eq $true){
        $log_body = $body
        try{$log_body.Password = "<Redacted>"}Catch{}
        try{$log_body.Properties.ServerPassword = "<Redacted>"}Catch{}
        Write-KFLog -Message "CertStore_Approve_Submit" -Artifact $log_body
    }

    return (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores/Approve" -Body $body -Method POST)

}

# Function to approve certificate store
function Approve-KF-CertificateStore-PKCS12{
 param(
        [Parameter(Mandatory,HelpMessage='Certificate store ID')]
            [string]$CertStoreID,        
        [Parameter(Mandatory,HelpMessage='Certificate store type ID')]
            [string]$CertStoreTypeID,
        [Parameter(HelpMessage='Return pending certificate stores')]
            [string]$ContainerID,
        [Parameter(HelpMessage='Store password of the cert store')]
            [string]$StorePassword,
        [Parameter(Mandatory,HelpMessage='Server username')]
            [string]$ServerUserName,
        [Parameter(Mandatory,HelpMessage='Server password')]
            [string]$ServerPassword,
        [Parameter(HelpMessage='Use SSL')]
            [string]$UseSSL,
        [Parameter(HelpMessage='Default file permission to use on Linux Server')]
            [string]$LinuxFilePermissionOnCreate,
        [Parameter(HelpMessage='Default file owner to use on Linux Server')]
            [string]$LinuxFileOwnerOnCreate
    )

    # Set values not provided to False
    IF(!$UseSSL){
        $UseSSL = $false
    }

    # Set container ID to null if one wasn't provided.
    IF(!$ContainerID){
        $ContainerID = '""'
    }ELSE{
        $ContainerID = [int]$ContainerID
    }

    IF(!$LinuxFilePermissionOnCreate){
        $LinuxFilePermissionOnCreate = ''
    }
    IF(!$LinuxFileOwnerOnCreate){
        $LinuxFileOwnerOnCreate = ''
    }

    ## Secret Values ##
    # Ensure double backslash is included in username
    IF($ServerUserName -like "*\*" -and $ServerUserName -notlike "*\\*"){
        $ServerUserName = $ServerUserName.Replace("\","\\")
    }
    $username_secret = @{"SecretValue"=$ServerUsername}
    $username_value = @{"value"=$username_secret}
    $password_secret = @{"SecretValue"=$ServerPassword}
    $password_value = @{"value"=$password_secret}
   
    # Store pass
    IF(!$StorePassword){
        $storepass_secret = @{"SecretValue"=$null}
        $storepass_string = (($storepass_secret | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    }ELSE{
        $storepass_secret = @{"SecretValue"=$StorePassword}
        $storepass_string = (($storepass_secret | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    }
       
    # Create hashtable
    $property = @{"ServerUsername"=$username_value}
    $property.Add("ServerPassword",$password_value)
    $property.Add("ServerUseSsl",$UseSSL)
    $property.Add("LinuxFilePermissionsOnStoreCreation",@{"value"=$LinuxFilePermissionOnCreate})
    $property.Add("LinuxFileOwnerOnStoreCreation",@{"value"=$LinuxFileOwnerOnCreate})
    
    # Convert store pass to JSON string
    $property_string = (($property | ConvertTo-Json -Depth 100 -Compress) | Out-String)
    $property_string = $property_string.Replace('"','\"')

    # Build final body
    $body = "[{
      `"ContainerId`" `: `"$CertStoreContainerID`",
      `"CertStoreType`": $CertStoreTypeID,
      `"Password`": $storepass_string,
      `"Properties`": `"$property_string`",
      `"Id`" `: `"$CertStoreID`"
    }]"
    
    # Log if trace is enabled
    IF($log_trace -eq $true){
        $log_body = $body
        try{$log_body.Password = "<Redacted>"}Catch{}
        try{$log_body.Properties.ServerPassword = "<Redacted>"}Catch{}
        Write-KFLog -Message "CertStore_Approve_Submit" -Artifact $log_body
    }

    return (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores/Approve" -Body $body -Method POST)

}

# Function to set a certificate store schedule
function Set-KF-CertStoreSchedule{
 param(
    [Parameter(Mandatory,HelpMessage='Certificate store ID')]
        [string]$CertStoreID,
    [Parameter(HelpMessage='Interval Minutes')]
        [ValidateRange(1,60)]
        [int]$IntervalMinutes,
    [Parameter(HelpMessage='DateTime to run')]
        [string]$Daily,
    [Parameter(HelpMessage='Day/Time to schedule for one time run.')]
        [string]$Once,
    [Parameter(HelpMessage='Run immediately')]
        [switch]$Immediately
    )

    # Date format to use in schedules
    $dateformat = "yyyy-MM-dd'T'HH:mm:ss'Z'"

    # Validate provided parameters
    IF($IntervalMinutes -and $Daily){
        throw "You cannot specify a Daily and Inverval schedule simultaneously"
    }
        
    # Define master scedule
    $body = @{}

    # Add the cert store to body
    $body.Add("StoreIds",@($CertStoreID))

    # Create schedule
    $schedule = @{}
    # Set Variables
    IF($Immediately){
        $schedule.Add("Immediate",$true)
    }
    IF($IntervalMinutes){
        $schedule.Add("Interval",@{"Minutes"=$IntervalMinutes})
    }
    IF($Daily){
        $daily_datetime = (Get-Date $Daily)
        $schedule.Add("Daily",@{"Time"=$daily_datetime})
    }
    IF($Once){
        $Once_datetime = (Get-Date $once)
        $schedule.Add("ExactlyOnce",@{"Time"=$Once_datetime})
    }

    # Add schedule to body
    $body.add("Schedule",$schedule)
    
    # Convert to JSON
    $body = $body | ConvertTo-Json -Depth 100

    # Log if trace is enabled
    IF($log_trace -eq $true){
        Write-KFLog -Message "CertStore_Schedule_Submit" -Artifact $body
    }

    #return $Body
    return (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call "/CertificateStores/Schedule" -Body $body -Method POST)

}

function Create-PendingCert-DataTable{

    $script:PendingCert_Content = $null
    $script:PendingCert_Content = New-Object System.Data.DataTable
 
    ## Create Columns ##
    $col1 = New-Object System.Data.DataColumn("CertStoreTypeId") 
    $col2 = New-Object System.Data.DataColumn("ContainerId") 
    $col3 = New-Object System.Data.DataColumn("MachineName")
    $col4 = New-Object System.Data.DataColumn("UseSSL") 
    $col5 = New-Object System.Data.DataColumn("ServerUsername") 
    $col6 = New-Object System.Data.DataColumn("ServerPassword")
    $col7 = New-Object System.Data.DataColumn("StorePath")  
    $col8 = New-Object System.Data.DataColumn("CertStorePassword") 
    $col9 = New-Object System.Data.DataColumn("IncludesChain(true/false)") 
    $col10 = New-Object System.Data.DataColumn("IsRSAPrivateKey(true/false)(PEM only)")
    $col11 = New-Object System.Data.DataColumn("IsTrustStore(true/false)(PEM only)")
    $col12 = New-Object System.Data.DataColumn("SeparatePrivateKeyFile(FilePath)(PEM only)")
    $col13 = New-Object System.Data.DataColumn("LinuxFilePermissionOnCreate") 
    $col14 = New-Object System.Data.DataColumn("LinuxFileOwnerOnCreate")  
    $col15 = New-Object System.Data.DataColumn("InventorySchedule(Minutes)") 
    $col16 = New-Object System.Data.DataColumn("InventorySchedule(Daily(Time))") 
    $col17 = New-Object System.Data.DataColumn("InventorySchedule(Once(DateTime))")
     
    ### Adding Columns for DataTable ### 
    $script:PendingCert_Content.columns.Add($col1) 
    $script:PendingCert_Content.columns.Add($col2) 
    $script:PendingCert_Content.columns.Add($col3)
    $script:PendingCert_Content.columns.Add($col4)
    $script:PendingCert_Content.columns.Add($col5)
    $script:PendingCert_Content.columns.Add($col6)
    $script:PendingCert_Content.columns.Add($col7)
    $script:PendingCert_Content.columns.Add($col8)
    $script:PendingCert_Content.columns.Add($col9)
    $script:PendingCert_Content.columns.Add($col10)
    $script:PendingCert_Content.columns.Add($col11) 
    $script:PendingCert_Content.columns.Add($col12) 
    $script:PendingCert_Content.columns.Add($col13) 
    $script:PendingCert_Content.columns.Add($col14) 
    $script:PendingCert_Content.columns.Add($col15)
    $script:PendingCert_Content.columns.Add($col16)
    $script:PendingCert_Content.columns.Add($col17) 

    return $script:PendingCert_Content

}

function Add-PendingCert-Row{
    
    param(
    [parameter(Mandatory)]
    [int]$CertStoreTypeId,
    [int]$ContainerId,
    [parameter(Mandatory)]
    [string]$MachineName,
    [parameter(Mandatory)]
    [string]$StorePath
    )
   
    $row = $script:PendingCert_Content.NewRow() 
    $row["CertStoreTypeId"] = $CertStoreTypeId
    
    IF($ContainerId){
        $row["ContainerId"] = $ContainerId
    }

    $row["MachineName"] = $MachineName
    $row["StorePath"] = $StorePath
    
    $script:PendingCert_Content.rows.Add($row)
      
}


################
# Start script #
################

# Define log file for this run
$log_fullname = ($log_dir+"\"+$log_fileName+"_"+(Get-Date -Format "yyyyMMdd")+".csv")

Write-KFLog -Message "Process started"

# Clear some variables
$Pending_CertStores = $null
$Check_Pending_CertStores = $null
$discovery_prompt = $null
$prompt_cert_approval = $null
$import_chosen = $null

# Export machine details file with headers if it doesn't already exist
try{
    Get-Item -Path $machine_details -ErrorAction Stop > $null
}Catch{
    $machine_details_headers  = '"StoreType(RFJKS/RFPEM/RFPKCS12)","OrchestratorID","MachineName","ServerUsername","ServerPassword","UseSSL","DirectoriesToSearch","DirectoriesToIgnore","Extensions","FilePatternToMatch","IncludePKS12","FollowSymLinks"'
    Out-File -FilePath $machine_details -InputObject $machine_details_headers -Encoding ascii
    cls
    Write-KFLog -Message "Created Machine Details file" -Artifact $machine_details

    write-host `n
    Write-Host -ForegroundColor Yellow "A machine details file was not found. which is needed for creating Keyfactor Discovery Jobs."
    Write-Host -ForegroundColor Yellow "A file with the required headers has been created at: $machine_details"
    
    # Give the user the option to retrieve their orchestrator IDs
    Write-Host `n
    Write-Host "You must define an Keyfactor Orchestrator ID within the new file, which will be used for creating discovery jobs."
    IF((Read-Host -Prompt "Do you wish to print your environment's Keyfactor Orchestrators now? (y/n)") -like "*y*"){

        # Retrieve orchestrators
        $orchestrators = Get-KF-Orchestrator

        IF($orchestrators){
        write-host `n
        $orchestrators | ForEach-Object{
                                        Write-Host $_.AgentID -nonewline
                                        Write-Host -ForegroundColor Green (" | "+$_.ClientMachine)
                                        }

        $orchestrators | ForEach-Object{Write-KFLog -Message "Registered Orchestrator" -Artifact ($_.AgentID+"|"+$_.ClientMachine)}
        }ELSE{
            Write-Host "No orchestrators were found."
            Write-KFLog -Message "Warning: No Keyfactor Orchestrators were found. A Keyfactor Orchestrator is required to schedule discovery jobs."
        }
    } 

    write-host `n   
    pause

    $machine_details = $null
}

# Test the provided API information and credentials
try{
    Connect-KFAPI
    Write-KFLog -Message "API connection test successful" -Artifact $apiurl
}Catch{
    Write-Host -ForegroundColor Red "The API connection failed while using the provided information:"
    Write-Host "API URL: $apiurl"
    Write-Host "Username: $username"
    Write-Host `n
    Write-Host -ForegroundColor Yellow "Please confirm the provided API information is correct."
    Write-KFLog -Message "API connection test failed." -Artifact $apiurl
    break
}

# Check if machine details file exist, if so prompt to run discovery schedule
try{
    IF(Get-Item -Path $machine_details -ErrorAction Stop){
        cls
        Write-Host `n
        write-host "A machine details file was found at the expected location: " -NoNewline
        Write-Host -ForegroundColor Green  $machine_details

        $discovery_prompt = (Read-Host -Prompt "Do you wish to create new discovery jobs with this file? (y/n)")

    }ELSEIF($discovery_prompt -notlike "*y*"){
        Write-KFLog -Message "Skipped discovery"
        throw "No discovery"
    }
}Catch{
    Write-Host `n
    Write-Host -ForegroundColor Yellow "Either no machine details file was found, it was just created, or user skipped discovery import."
}

# If discovery import was chosen
IF($discovery_prompt -like "*y*"){
    write-host `n
    Write-Host -ForegroundColor Yellow "Importing discovery jobs"
    Write-KFLog -Message "Importing discovery jobs" -Artifact $machine_details

    # Import
    $machine_details_content = (Import-Csv -Path $machine_details)

    foreach($machine in $machine_details_content){

       write-host "Machine: " -nonewline
       write-host -foregroundcolor Green $machine.MachineName
       Write-KFLog -Message "Scheduling discovery job" -Artifact ($machine.MachineName+"|"+$machine.'StoreType(RFJKS/RFPEM/RFPKCS12)')
       New-KF-DiscoveryJob -OrchestratorID $machine.OrchestratorID -CertStoreTypeShortName $machine.'StoreType(RFJKS/RFPEM/RFPKCS12)' -MachineName $machine.MachineName -UseSSL $machine.UseSSL -ServerUsername $machine.ServerUsername -ServerPassword $machine.ServerPassword -directoriesToScan $machine.DirectoriesToSearch `
       -directoriesToIgnore $machine.DirectoriesToIgnore -FileExtension $machine.Extensions -FilePatternToMatch $machine.FilePatternToMatch -IncludePKCS12 $machine.IncludePKS12 -FollowSymLinks $machine.FollowSymLinks

    }

    write-host "Finished Discovery Job scheduling."

    write-host `n
    write-host "Printing currently scheduled jobs:"
    $scheduledJobs = Get-KF-DiscoveryJobs
    $scheduledJobs | ForEach-Object{Write-Host -ForegroundColor Green ($_.JobType+" | "+$_.Orchestrator+" | "+$_.Requested)}
}

# Retrieve pending certificate stores
write-host `n
write-host "Checking for pending Certificate Stores..."
$Pending_CertStores = Get-KF-CerificateStores -ReturnPending

# First check if a pending cert store file exist with info
$Check_Pending_CertStores = (Get-ChildItem -Path $Pending_CertStores_Dir | where {$_.Name -like "$Pending_CertStores_FileName*"} | Sort-Object "LastWriteTime" -Descending)

# Print message
IF($Check_Pending_CertStores -and $Pending_CertStores){
    write-host `n
    Write-Host -ForegroundColor Yellow "An existing Pending Certificate Stores file has been found."
    Write-Host -ForegroundColor Yellow "If certificate store details have been added to this file, it can now be imported to approve pending certificate stores."
    Write-Host `n

    # Prompt if certificate stores should be approved
    $prompt_cert_approval = Read-Host "Do you wish to continue with Certificate Store Approval? (y/n)"

    write-host `n

}ELSEIF(!$Pending_CertStores){
    write-host -ForegroundColor Yellow "No pending certificate stores were found."
    write-host `n
    Write-KFLog -Message "No pending certificates stores found."
}

# If prompt is yes, loop through found files to select one.
IF($Pending_CertStores -and $Check_Pending_CertStores -and $prompt_cert_approval -like "*y*"){

    Write-KFLog -Message "Searching for potential Pending Certificate Stores files"

    # Loop through pontential files
    $file_count = 0
    while($Check_Pending_CertStores[$file_count]){
    
        $import_pending_stores = $null
        $import_file_prompt = $null
        Write-Host -ForegroundColor Yellow $Check_Pending_CertStores[$file_count].name
        $import_file_prompt = Read-Host -Prompt "Use this file to approve certificate stores?"

        # If user chooses correct file
        IF($import_file_prompt -like "*y*"){
            $import_chosen = $Check_Pending_CertStores[$file_count].FullName
            Write-KFLog -Message "Pending Cert Store file chosen" -Artifact $import_chosen
            break
        }
        $file_count++
    }
}

# If an Pending Cert Store import file was chosen, use it to approve certificate stores
IF($import_chosen){

    ## Retrieve pending certificate stores ##

    # Retrieve pending certificate stores
    $Pending_CertStores = Get-KF-CerificateStores -ReturnPending
    
    IF($Pending_CertStores){

        Write-KFLog -Message "Pending Certificate Stores found" -Artifact $Pending_CertStores.Id.count

        ## Import pending cert store file ##
        $import_pending_stores = Import-Csv -Path $import_chosen

        # Import machine details file #
        try{
            $import_machine_details = Import-Csv -Path $machine_details -ErrorAction Stop
        }Catch{
            Write-KFLog "Machine Details file could not be imported" -Artifact $import_machine_details
        }

        # Loop through pending stores
        foreach($store in $Pending_CertStores){
            
            write-host `n
            Write-Host ("Processing Certificate Store: "+$store.DisplayName)
            Write-KFLog -Message "Processing Pending Cert Store" -Artifact $store

            # Reset variables
            $machine_creds = $null
            $serverUsername = $null
            $ServerPassword = $null
            $machine_split = $null
            $matched_store = $null

            # Parse machine name
            $machine_split = ($store.ClientMachine).Split(":")
            $machine_name = $machine_split[1].Replace("//","")

            # Match a pending store with the imported details
            $matched_store = $import_pending_stores | where {$_.MachineName -eq $machine_name -and $_.StorePath -eq $store.Storepath}

            write-host `n
            Write-Host "`t Pending Certificate Store found in import: "  -NoNewline
            write-host -ForegroundColor Green $machine_name

            # Default to using import pending cert store file
            IF($matched_store.ServerUsername){
            
                write-host "`t Credentials found for machine in Pending Certificate Stores file!"            
                Write-KFLog -Message "Credentials found in Pending Certificate Store file. Using these." -Artifact $matched_store.ServerUsername

                $ServerUsername = $matched_store.ServerUsername
                $ServerPassword = $matched_store.ServerPassword

            } # Else, use machine details file, if it exist.
            ELSEIF($import_machine_details){
            
                write-host "`t Credentials not found in Pending certificate store file. Checking $machine_details"

                # Determine if machine credentials exist in machine credentials file
                $machine_creds = $import_machine_details | where {$_.MachineName -eq $machine_name} | select -First 1

                IF($machine_creds){
                    write-host  "`t Credentials found for machine: " -NoNewline
                    Write-Host -ForegroundColor Green $machine_creds.ServerUserName
                    Write-KFLog -Message "Credentials defined in Machine Details file will be used" -Artifact $machine_creds.ServerUserName

                    $ServerUsername = $machine_creds.ServerUserName
                    $ServerPassword = $machine_creds.ServerPassword
                }
            }
        
            # If mandatory values are provided, approve the certificate store
            IF($serverUsername -and $ServerPassword){

            # Find the friendly name for this cert store type
            $CertStoreTypeName = (Submit-KFAPI -KeyfactorAPI_URL $apiurl -API_Call ("/CertificateStoreTypes/"+[string]$store.certstoretype) -Method Get).ShortName
            
            Write-KFLog -Message "Retrieved certificate store type shortname" -Artifact $CertStoreTypeName

            # Call the appropriate approve function for the given certificate store
            
            # RFPEM
            IF($CertStoreTypeName -eq "RFPEM"){

               try{
                    Approve-KF-CertificateStore-PEM -CertStoreID $store.Id -CertStoreTypeID $matched_store.CertStoreTypeId -ContainerID $store.ContainerId -StorePassword $matched_store.CertStorePassword -ServerUserName $ServerUsername -ServerPassword $ServerPassword -UseSSL $matched_store.UseSSL `
                    -IncludesChain $matched_store.'IncludesChain(true/false)' -IsTrustStore $matched_store.'IsTrustStore(true/false)(PEM only)' -IsRSAPrivateKey $matched_store.'IsRSAPrivateKey(true/false)(PEM only)' -SeparatePrivateKeyFile $matched_store.'SeparatePrivateKeyFile(FilePath)(PEM only)' `
                    -LinuxFilePermissionOnCreate $matched_store.LinuxFilePermissionOnCreate -LinuxFileOwnerOnCreate $matched_store.LinuxFileOwnerOnCreate 
                    
                    Write-Host -ForegroundColor Green "`t Approved!"
                    Write-KFLog -Message "Approved certificate store"
                }Catch{
                    Write-Host -ForegroundColor Red "`t Could not approve. See log..."
                    Write-KFLog -Message "Error while approving" -Artifact $_
                }
            }

            # RFPKCS12
            IF($CertStoreTypeName -eq "RFPKCS12"){
                try{                    
                    Approve-KF-CertificateStore-PKCS12 -CertStoreID $store.id -CertStoreTypeID $matched_store.CertStoreTypeId -ContainerID $store.ContainerId -StorePassword $matched_store.CertStorePassword -ServerUserName $serverUsername -ServerPassword $ServerPassword -UseSSL $matched_store.UseSSL -LinuxFilePermission $matched_store.LinuxFilePermissionOnCreate -LinuxFileOwner $matched_store.LinuxFileOwnerOnCreate
                    
                    Write-Host -ForegroundColor Green "`t Approved!"
                    Write-KFLog -Message "Approved certificate store"
                }Catch{
                    Write-Host -ForegroundColor Red "`t Could not approve. See log..."
                    Write-KFLog -Message "Error while approving" -Artifact $_
                }
            }
            # RFPKCS12
            IF($CertStoreTypeName -eq "RFJKS"){
                try{                    
                    Approve-KF-CertificateStore-JKS -CertStoreID $store.id -CertStoreTypeID $matched_store.CertStoreTypeId -ContainerID $store.ContainerId -StorePassword $matched_store.CertStorePassword -ServerUserName $serverUsername -ServerPassword $ServerPassword -UseSSL $matched_store.UseSSL -LinuxFilePermission $matched_store.LinuxFilePermissionOnCreate -LinuxFileOwner $matched_store.LinuxFileOwnerOnCreate

                    Write-Host -ForegroundColor Green "`t Approved!"
                    Write-KFLog -Message "Approved certificate store"
                }Catch{
                    Write-Host -ForegroundColor Red "`t Could not approve. See log..."
                    Write-KFLog -Message "Error while approving" -Artifact $_
                }
            }

                # Set provided schedule
                IF($matched_store.'InventorySchedule(Daily(Time))'){
                    try{
                        Set-KF-CertStoreSchedule -CertStoreID $store.Id -Daily $matched_store.'InventorySchedule(Daily(Time))'
                        Write-KFLog -Message "Schedule set successfully"
                    }Catch{
                        write-host -ForegroundColor Red "`t Schedule could not be set"
                        Write-KFLog -Message "Schedule could not be set" -Artifact $_
                    }
                }
                IF($matched_store.'InventorySchedule(Minutes)'){
                    try{
                        Set-KF-CertStoreSchedule -CertStoreID $store.Id -IntervalMinutes $matched_store.'InventorySchedule(Minutes)'
                        Write-KFLog -Message "Schedule set successfully"
                      }Catch{
                        write-host -ForegroundColor Red "`t Schedule could not be set"
                        Write-KFLog -Message "Schedule could not be set" -Artifact $_
                    }
                }
                IF($matched_store.'InventorySchedule(Once(DateTime))'){
                    try{
                        Set-KF-CertStoreSchedule -CertStoreID $store.Id -Once $matched_store.'InventorySchedule(Once(DateTime))'
                        Write-KFLog -Message "Schedule set successfully"
                      }Catch{
                        write-host -ForegroundColor Red "`t Schedule could not be set"
                        Write-KFLog -Message "Schedule could not be set" -Artifact $_
                    }
                }

            }
            IF(!$matched_store.CertStorePassword){
                write-host -ForegroundColor Yellow "`t Warning: Certificate Store file password not provided. This may affect Keyfactor reading the Certificate Store file properly."
                Write-KFLog -Message "Warning: Missing CertStore Password" -Artifact $store.DisplayName
            }
        }

        write-host `n
        write-host -ForegroundColor Green "Finished Certificate Approval Process"
        write-host `n
        Write-KFLog -Message "Certificate Store Approval finished"
    }
}

IF($Pending_CertStores){

    # Prompt to export the currently pending certificate stores.
    $export_prompt = (Read-Host -Prompt "Do you wish to export the current pending certificate stores? (y/n)")

        IF($export_prompt -like "*y*"){

        Write-KFLog -Message "Exporting current pending cert stores"

        # Retrieve pending certificate stores
        $Pending_CertStores = Get-KF-CerificateStores -ReturnPending

        # Create data table
        Create-PendingCert-DataTable

        # Loop through pending certificate stores
        foreach($store in $Pending_CertStores){
        
                # Parse machine name
                $machine_split = ($store.ClientMachine).Split(":")
                $machine_name = $machine_split[1].Replace("//","")
                write-host ("Exported: "+$store.DisplayName)
                Add-PendingCert-Row -CertStoreTypeId $store.CertStoreType -ContainerId $store.ContainerId -MachineName $machine_name -StorePath $store.StorePath
        }

        # Export any pending certs to file
        IF($script:PendingCert_Content.rows.count -gt 0){

            Write-Host `n
            Write-Host "Exported file located in: " -NoNewline
            Write-Host -ForegroundColor Green $Pending_CertStores_Dir
            Write-Host -ForegroundColor Yellow "Add the required details in the exported file and then run this script again to approve Certificate Stores."

            # If the file already exist, export a new one with additional timestamp     
                $script:PendingCert_Content | export-csv -Path ($Pending_CertStores_Dir+"\"+$script:Pending_CertStores_FileName+"_"+(Get-Date -Format yyyyMMdd_hhmmss)+".csv") -NoTypeInformation  
            
                Write-KFLog -Message "Pending certificate stores exported."
                 
        }ELSE{
            Write-KFLog -Message "No pending certificate stores found to be exported."
        }
    }
}

Write-KFLog -Message "Process finished"
Write-Host "Script finished"

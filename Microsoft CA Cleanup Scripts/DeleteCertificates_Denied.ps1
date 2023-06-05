#######################################################################################################
#
#
#	Usage:  This script will delete expired certs form the CA Database
#           base on specific variables. 
#
#
####################################################################################################

#******************************************** Config Section ********************************************
# Define Certificate Templates used in deletes
# $certTemplateList = @("1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.4630009.7353665","1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.6071320.15324429","1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.8128049.3022941")
# $certTemplateList = @("1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.4630009.7353665")
# $certTemplateList = @("1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.6071320.15324429")
# $certTemplateList = @("1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.8128049.3022941")

# CA Exchange Certificate Template
# $certTemplateList = @("CAExchange","1.3.6.1.4.1.311.21.8.7737339.9487295.4868765.4212109.7263428.27.4630009.7353665")
# $certTemplateList = @("HeartbeatCert")

# Disposition	Description
# 20		    certificate was issued
# 21		    certificate is revoked
# 30		    certificate request failed
# 31		    certificate request is denied
$CertDisposition = "31"
#******************************************** Config Section  ********************************************

#********************************************** Usage *************************************************************
#  .\DeleteCertificates.ps1 -Scan  -Denied -DeleteCerts"
#  Case insensitive inputs.  The order, of the parameters, does not matter
#       -Scan : Scans for expired certificates to delete based on predefined certificate templates
#       -Denied : Performs the deletion of denied certificate requests from the CA DB
#       -DeleteCerts : Performs the deletion of certificates from the CA DB
#
#  * Retrieve certs to delete only 
#       .\DeleteCertificates.ps1 –scan 
# 
#  * Perform deletes based on previously ran "-Scan" 
#    Deletes the certs based on the data in the “CertsToDelete.txt” file.  It will not rescan the CA DB.
#       .\DeleteCertificates.ps1 –DeleteCerts
#
#  * Scans the CA DB for denied cert requests then delete the requests.
#       .\DeleteCertificates.ps1 –scan -Denied –DeleteCerts
# 
#   
#******************************************************************************************************************

####################
# Variable Section
####################

$enableScan = $false
$enableDenied = $false
$enableDeleteCerts = $false
$daysToModify = 0
$hoursToModify = 0
$minutesToModify = 0

# Get current directory
$CurrentPath = $PWD

#File Paths
$CertUtilViewFile = "$CurrentPath\CertUtil-View.txt"  #stores output from "certutil -view command
$CertsToDeleteFile = "$CurrentPath\CertsToDelete.txt" #stores the certificates that will be deleted
$deletedCertsFile = "$CurrentPath\DeletedCerts.log"  #Logs all certs that were deleted

# $myinvocation.MyCommand.Name provides the PS script name when called outside of a function.
# The name of the script is used when registering the evnet source  
$source = "CSS Delete Certificates"

###########################################################################
# Register Event log source.  Required to write messages to the event log  
# The SourceExists() will search through all event logs and may 
# throw an exception if the account does not have Administrator privileges 
###########################################################################
try
{
    if ([System.Diagnostics.EventLog]::SourceExists($source) -eq $false)
    {
        # Requires Administrator access to create or delete an event source
        [System.Diagnostics.EventLog]::CreateEventSource($source, "Application")
    }
}
catch
{
    Write-Host "****************************************************************************************" -ForegroundColor Red
    Write-Host "*****************************  ERROR  *  ERROR  *  ERROR  ******************************" -ForegroundColor Red
    Write-Host "****************************************************************************************" -ForegroundColor Red
    Write-Host "Event Source, $source, cannot be created." -ForegroundColor Red
    Write-Host "The user/service account does not have the appropriate permissions to create the source." -ForegroundColor Red
    Write-Host "****************************************************************************************" -ForegroundColor Red
    Write-Host "*****************************  ERROR  *  ERROR  *  ERROR  ******************************" -ForegroundColor Red
    Write-Host "****************************************************************************************" -ForegroundColor Red
    exit
}

#####################################################################################
# LogEvent: Function to log events to the Application event log and write to console.
# Parameters:
# $eventMessage:  Message text
# $eventLogEntryType: Event log severity.  Following are the valuses used: 
#     Error:  An error event. 
#             Indicates a significant problem the user should know about; usually 
#             a loss of functionality or data.  Program terminates.
#     Information: An information event. 
#                  Informational message only. Successful operation.
#     Warning: A warning event. 
#              Indicates a problem that is not immediately significant, but  
#              may signify conditions that could cause future problems.
# Example: logEvent "Information Text" "Information"
#####################################################################################    
function LogEvent($eventMessage, $eventLogEntryType)            
{
    $eventLog=new-object System.Diagnostics.EventLog("Application")
    $eventLog.Source=$source

    switch ($eventLogEntryType)  #Defines the message ID based on the Event log entry type
    {
        "Information"
        {
            $eventID = 0
            Write-Host $eventMessage

            $eventLog.WriteEntry($eventMessage, [system.Diagnostics.EventLogEntryType]::$eventLogEntryType, $eventID)
        }
        "Warning"
        {
            $eventID = 1
            Write-Host "****************************************************************************************" -ForegroundColor Yellow
            Write-Host "***************************  WARNING *  WARNING  *  WARNING  ***************************" -ForegroundColor Yellow
            Write-Host "****************************************************************************************" -ForegroundColor Yellow
            Write-Host $eventMessage -ForegroundColor Yellow
            Write-Host "****************************************************************************************" -ForegroundColor Yellow
            Write-Host "***************************  WARNING *  WARNING  *  WARNING  ***************************" -ForegroundColor Yellow
            Write-Host "****************************************************************************************" -ForegroundColor Yellow

            $eventLog.WriteEntry($eventMessage, [system.Diagnostics.EventLogEntryType]::$eventLogEntryType, $eventID)
        }
        "Error"
        {
            $eventID = 2
            Write-Host "****************************************************************************************" -ForegroundColor Red
            Write-Host "*****************************  ERROR  *  ERROR  *  ERROR  ******************************" -ForegroundColor Red
            Write-Host "****************************************************************************************" -ForegroundColor Red
            Write-Host $eventMessage -ForegroundColor Red
            Write-Host "$source terminated with errors" -ForegroundColor Red
            Write-Host "****************************************************************************************" -ForegroundColor Red
            Write-Host "*****************************  ERROR  *  ERROR  *  ERROR  ******************************" -ForegroundColor Red
            Write-Host "****************************************************************************************" -ForegroundColor Red

            $eventLog.WriteEntry("$Source terminated with errors:`n`r$eventMessage", [system.Diagnostics.EventLogEntryType]::$eventLogEntryType, $eventID)
            Exit
        }
   }
}

function Determine-Certs-To-Delete()
{
    LogEvent "Determine-Certs-To-Delete() --> Started" "Information"

    Try
    {
        ####################################################################################################
        # caName: Name of the CA based on the CA Name from the CA Registry property "Active" in
        # HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration
        ####################################################################################################
        $activeCA = (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration -Name Active -ErrorAction Stop).Active 
        $caServerName = (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$activeCA -Name CAServerName -ErrorAction Stop).CAServerName  
        $ca = "$caServerName\$activeCA"
    }
    Catch
    {
        LogEvent "Unable to determine CA Name`n$_" "Error"
    } 

    #Initialize variables
    $certsMarkedForDeleteCounter = 0

    # define current date/time
    $ModifyDate = New-TimeSpan -Days $daysToModify -Hours $hoursToModify -Minutes $minutesToModify
    $CurrentTimeStampDeletes = (Get-Date) - $ModifyDate
    $CurrentTimeStampDeletes = $CurrentTimeStampDeletes -F 'MM/dd/yyyyhh:mmtt'
    $certRestrict = '"NotBefore<='+$CurrentTimeStampDeletes+''
    
    
    try
    {
        #Create (replace if exists) the CertUtil -view output file
        $streamWriterCV = [System.IO.File]::CreateText($CertUtilViewFile)
    }
    catch
    {
        LogEvent $_ "Error"
    }
       
    # foreach ($certTemplateItem in $certTemplateList)  #loops through cert templates to determine which certs to delete
    # {
        if ($CA -ne $null)
        {
            $CAName = "-config `"$CA`""
        }
        
        if ($CertDisposition -ne $null)
        {
            $certDisp = "disposition=$CertDisposition"
            $certDisp = ''+$certDisp+'"'
        }

        
        #if ($enableDenied -eq $true)
        #{
        #    $certRestrict = '"'+$certDisp+'"'
        #}
        #else
        #{
        #    $certRestrict = '"NotAfter<='+$CurrentTimeStampDeletes+'"'
        #}

        $ExpiredCerts = "certutil –view $CAName –restrict $certRestrict,$certDisp –out `"RequestID,SerialNumber,CertificateTemplate,NotBefore,NotAfter`""

        # $ExpiredCerts = "certutil –view $CAName –restrict `"NotAfter<=$CurrentTimeStampDeletes`" –out `"RequestID,SerialNumber,CertificateTemplate,NotBefore,NotAfter`""

        #execute the certutil command and write to a file
        # LogEvent "Processing Certificate Template OID: $certTemplateItem" "Information"
        LogEvent "Executing command: $ExpiredCerts" "Information"
        
        #run certutil -View
        $cmdResponse = Invoke-Expression $ExpiredCerts
        
        if ($cmdResponse[$cmdResponse.Count-1].Contains("command completed successfully."))
        {
            foreach ($line in $cmdResponse)
            {
                $streamWriterCV.WriteLine($line)
            }
         }
         else
         {
            $streamWriterCV.Close()
            #log the last two lines of the file (contains error message from certutil -view)
            $errMsg1=$cmdResponse[$cmdResponse.Count-1]
            $errMsg2=$cmdResponse[$cmdResponse.Count-2]
            LogEvent "$errMsg1`n$errMsg2" "Error"
         }
        $streamWriterCV.flush()
        LogEvent "Completed processing Certificate Template OID: $certTemplateItem" "Information"
    # }
    $streamWriterCV.Close()
    $streamWriterCV.Dispose()

    try
    {
        #Create (replace if exists) the Certs to delete file
        $streamWriterCD = [System.IO.File]::CreateText($CertsToDeleteFile)
        #Open file for read
        $streamReaderCV = [System.IO.File]::OpenText($CertUtilViewFile)
    }
    catch
    {
        LogEvent $_ "Error"
    } 

    try
    {
        for(;;)
        {
            $line = $streamReaderCV.ReadLine()

            if ($line -eq $null) { break }  #read to end of file...exit for()

            $split = $line.Split(":",2)
            $split[0] = $split[0].Trim()
        
            switch ($split[0])
            {
                "Issued Request ID" 
                {   
                    $splitHexVal = $split[1].Split()  #split hex value Request ID
                    $ReqID = [Convert]::ToInt64($splitHexVal[1],16)  #convert hex Request ID to integer
                    break
                }
                "Serial Number"
                {
                    $sn = $split[1].Trim()
                    break
                }
                "Certificate Template"
                {
                    $certTemplate = $split[1].Trim()
                    break
                }
                "Certificate Effective Date"
                {
                    $CertEffDate = $split[1].Trim()
                    break
                }
                "Certificate Expiration Date"
                {
                    $CertExpDate = $split[1].Trim()
                    $writeLine = "$ReqID;$sn;$certTemplate;$CertEffDate;$CertExpDate"
                    $streamWriterCD.WriteLine($writeLine)
                    $streamWriterCD.Flush()   #force write to file                 
                    $certsMarkedForDeleteCounter++
                    break
                }
                default {}
            }
        }
     }
     finally
     {
        $streamWriterCD.Close()
        $streamWriterCD.Dispose()
        $streamReaderCV.close()
        $streamReaderCV.Dispose()
     }

    LogEvent "Determine-Certs-To-Delete() --> $certsMarkedForDeleteCounter certificates marked for delete"  "Information"
}  

function Delete-Certs()
{
    LogEvent "Delete-Certs() --> Started" "Information"
    try
    {    
        #Open file for read
        $streamReaderCD = [System.IO.File]::OpenText($CertsToDeleteFile)
        #open log file for append.  Create if file does not exist    
        $streamWriterDC =  [System.IO.File]::AppendText($deletedCertsFile)   
    }
    catch
    {
        LogEvent $_ "Error"
    }    

    $deletedCertificateCounter = 0    
    Try
    {
        for ($i=0;$i -lt 8000;$i++)
        {
            $line = $streamReaderCD.ReadLine()
            if ($line -eq $null) { break }  #read to end of file...exit for()

            if ($line -ne $null) 
            {
                $split = $line.Split(";",2)  # only split in two messages
                $rowID = $split[0]
        
                #Define the certutil command
                $deleteCerts = "certutil –deleterow $rowID"
        
                $CurrentTimeStamp = Get-Date -Format "MM/dd/yyyy hh:mm.ffftt"
                $StartMsg = "Deletes started at $CurrentTimeStamp - $deleteCerts"
                $streamWriterDC.WriteLine($StartMsg)
               
                $cmdResponse = Invoke-Expression $deleteCerts

                if ($cmdResponse[$cmdResponse.Count-1].Contains("command completed successfully."))
                {
                    foreach ($line in $cmdResponse)
                    {
                        $streamWriterDC.WriteLine($line)
                    }
                    $deletedCertificateCounter++
                 }
                 else
                 {
                    $streamWriterDC.Close()
                    #log the last two lines of the file (contains error message from certutil -view) 
                    $errMsg1=$cmdResponse[$cmdResponse.Count-1]
                    $errMsg2=$cmdResponse[$cmdResponse.Count-2]
                    LogEvent "$errMsg1`n$errMsg2" "Warning"
                 }
                $streamWriterDC.flush() # flush buffer, force write to file
            }
        }
     }
     finally
     {
        $streamReaderCD.close()
        $streamReaderCD.Dispose()
     }

     LogEvent "Delete-Certs() --> $deletedCertificateCounter Certificates Deleted" "Information"
}

function Usage-Message()
{
    LogEvent "Invalid parameters.`nUsage:`n.\DeleteCertificates.ps1 -Scan - Denied -DeleteCerts
         -Scan : Scans for expired certificates to delete based on predefined certificate templates
         -Denied : Scans for denied certificate requests to delete
         -DeleteCerts : Performs the deletion of certificates from the CA DB" "Error"
}

#*********** Main()***************** 
# Clear screen
Clear-Host

LogEvent "DeleteCertificates --> Started" "Information"
$numberOfArgs = $args.Count

if (($numberOfArgs -lt 1) -or ($numberOfArgs -gt 3))  # No parms defined
{
    Usage-Message
}
else #correct number of parms
{
    for ($i=0; $i -lt $numberOfArgs; $i++)  # read input arguments
    {

        $arg = $args[$i]
        switch ($arg)
        {
            "-Scan"
            {   
                $enableScan = $true
                break
            }
            "-Denied"
            {   
                $enableDenied = $true
                break
            }
            "-DeleteCerts"
            {
                $enableDeleteCerts = $true
                break
            }
            default #Invalid parameters
            {
               Usage-Message
            }
        }
    }
}

if ($enableScan) #scan for certs to delete
{
    Determine-Certs-To-Delete  # calls function to create delete file
}

if ($enableDeleteCerts) #perform deletes
{
    Delete-Certs  # calls function to delete certs from CA DB
}

LogEvent "DeleteCertificates --> Ended" "Information"
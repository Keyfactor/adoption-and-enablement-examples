#######################################################################################################
#
#
#	Usage:  This script will delete expired issued and revoked certs, and certificate 
#           requests form the CA Database base on specific variables/configurations.
#
#
#	               				
#
####################################################################################################

#********************************************** Usage *************************************************************
#  .\DeleteCertificates.ps1 -Scan  -DeleteCerts"
#  Case insensitive inputs.  The order, of the parameters, does not matter
#       -Scan : Scans for expired certificates to delete based on predefined certificate templates
#       -DeleteCerts : Performs the deletion of certificates from the CA DB
#
#  * Retrieve certs to delete only 
#       .\DeleteCertificates.ps1 –scan 
# 
#  * Scans the CA DB for expired certs then delete the certs.
#       .\DeleteCertificates.ps1 –scan –DeleteCerts
#   
#******************************************************************************************************************

######################################################################
#
# Variables that can be modified by the user
#
######################################################################
# Disposition	Description
# 20		    certificate was issued
# 21		    certificate is revoked
# 30		    certificate request failed
# 31		    certificate request is denied
# Define certificates to delete by Dispositon
$certDispositionList = @(20,30,31)
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

#Days prior to today to removed certs (Must be 0 or a non-negative value)
$daysInThePastDeniedFailed = 0
$daysInThePastIssuedRevoked = 0

#Define which failed/denied certrequest is to be deleted base on the status code. 
# If no value defined,$StatusCodeList = @(""), then all failed/denied certificate requests are deleted 
#Example:
#   $StatusCodeList = @("")  #Deletes all failed/denied certificate requests
#   $StatusCodeList = @("0x80094812","0x80094012") 
#   $StatusCodeList = @("The permissions on the certificate","The EMail name is unavailable")
$StatusCodeList = @("") 

######################################################################
###                                                                ###
###          Do not modify the script beyond this point            ###
###                                                                ###
######################################################################
$enableScan = $false
$enableDeleteCerts = $false

# define date/time variables
$CurrentTimeStampDeletes = Get-Date
$FileNameTimestamp = get-date -format "yyyyMMddHHmmss"

# Get current directory
$CurrentPath = $PWD

#File Paths
$CertsToDeleteFile = "$CurrentPath\CertsToDelete_$FileNameTimestamp.txt" #stores the certificates that will be deleted
$deletedCertsFile = "$CurrentPath\DeletedCerts_$FileNameTimestamp.log"  #Logs all certs that were deleted

# $myinvocation.MyCommand.Name provides the PS script name when called outside of a function.ten
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

    #Do not allow negative values for $daysInThePastIssuedRevoked and $daysInThePastDeniedFailed variables
    if ($daysInThePastIssuedRevoked -lt 0)
    {
        LogEvent "Invalid value for daysInThePastIssuedRevoked variable" "Error"
    }
    else
    {
        $IssuedRevokedTimestamp = $CurrentTimeStampDeletes.AddDays(-$daysInThePastIssuedRevoked)
    }
    if ($daysInThePastDeniedFailed -lt 0)
    {
        LogEvent "Invalid value for daysInThePastDeniedFailed variable" "Error"
    }
    else
    {
         $DeniedFailedTimestamp = $CurrentTimeStampDeletes.AddDays(-$daysInThePastDeniedFailed)
    }

 
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


    try
    {
        #Create (replace if exists) the CertUtil -view output file
        $streamWriterCV = [System.IO.File]::CreateText($CertsToDeleteFile)
    }
    catch
    {
        LogEvent $_ "Error"
    }
 
    if ($certDispositionList.Count -eq 0)
    {
        LogEvent "Invalid parameters - Certificate Disposition Missing.  Define the certDispositionList `nvariable with a valid values." "Error"
    }

    
    foreach ($certDispositionItem in $certDispositionList)  #loops through cert Dispositions to determine which certs to delete. Applies specifi parms.
    {
        if ($CA -ne $null)
        {
            $CAName = "-config `"$CA`""
        }
        
        $dateParm = ""
        $outputFields = "RequestID,Request.Disposition,Request.DispositionMessage,Request.StatusCode,SerialNumber,CertificateTemplate,Request.SubmittedWhen,NotBefore,NotAfter,Request.RequesterName,Request.DistinguishedName,Request.CommonName,Request.Organization,Request.OrgUnit"
 
        # Determine date parameter for certutil command
        switch ($CertDispositionItem)
        {
            "20" 
            {   
                $certDispName = "Issued"
                $dateParm = "NotAfter<=$IssuedRevokedTimestamp" 
                $certDispParm = ",disposition=$CertDispositionItem"
                break
            }
            "21"
            {
                $certDispName = "Revoked"
                $dateParm = "NotAfter<=$IssuedRevokedTimestamp" 
                $certDispParm = ",disposition=$CertDispositionItem"
                break
            }
            "30" 
            {   
                $certDispName = "Failed"
                $dateParm = "Request.SubmittedWhen<=$DeniedFailedTimestamp"
                $certDispParm = ",disposition=$CertDispositionItem"
                break
            }
            "31" 
            {   
                $certDispName = "Denied"
                $dateParm = "Request.SubmittedWhen<=$DeniedFailedTimestamp"
                $certDispParm = ",disposition=$CertDispositionItem"
                break
            }
            default #no disposition is defined.  
            {
                LogEvent "Invalid parameters - Certificate Disposition Missing.  Define the certDispositionList `nvariable with a valid values." "Error"
            }
        }

        #generate the certutil command
        $ExpiredCerts = "certutil –view $CAName –restrict `"$dateParm $certDispParm`" –out `"$outputFields`" csv"

        LogEvent "Executing command: $ExpiredCerts" "Information"
        
        #execute the certutil command and write to a file
        $cmdResponse = ""
        $cmdResponse = Invoke-Expression $ExpiredCerts
 
        $lineCnt=0
        $cntOfCertsToDelete = 0
        foreach ($line in $cmdResponse)
        {
            if ($lineCnt -ne 0)  #Do not write header infomation (first line) to the file
            {
                #filter deletes of denied/failed certificate requessts
                if ((($CertDispositionItem -eq 30) -or ($CertDispositionItem -eq 31)) -and $StatusCodeList.Count -ne 0)  
                {
                    foreach ($statusCode in $StatusCodeList)
                    {
                        if ($line -like "*$statusCode*")  #delete certs with the specified status code
                        {
                            $streamWriterCV.WriteLine($line)
                            ++$cntOfCertsToDelete
                        }
                    }
                }
                else # remove expire issued and revoked certificates (disposition 20 and 21)
                {
                    $streamWriterCV.WriteLine($line)
                    ++$cntOfCertsToDelete
                }
            }
            ++$lineCnt
        }
        $streamWriterCV.flush()
       
        if (($CertDispositionItem -eq 20) -or ($CertDispositionItem -eq 21))
        {
            LogEvent "Determine-Certs-To-Delete() --> $cntOfCertsToDelete expired $certDispName certificates marked for delete"  "Information"
        }
        elseif (($CertDispositionItem -eq 30) -or ($CertDispositionItem -eq 31))
        {
            LogEvent "Determine-Certs-To-Delete() --> $cntOfCertsToDelete $certDispName certificate requests marked for delete"  "Information"
        }

    }
    LogEvent "Determine-Certs-To-Delete() - Completed processing" "Information"
    $streamWriterCV.Close()
    $streamWriterCV.Dispose()
    Clear-Variable -Name "cmdResponse"
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
        for ($i=0;$i -lt 1000000;$i++)
        {
            $line = $streamReaderCD.ReadLine()
            if ($line -eq $null) { break }  #read to end of file...exit for()

            if ($line -ne $null) 
            {
                $split = $line.Split(",",2)  # only split in two messages
                $rowID = $split[0]
        
                #Define the certutil command
                $deleteCerts = "certutil –deleterow $rowID"
        
                $GetTimeStamp = Get-Date -Format "MM/dd/yyyy hh:mm.ffftt"
                $StartMsg = "Deletes started at $GetTimeStamp - $deleteCerts"
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
    LogEvent "Invalid parameters.`nUsage:`n.\DeleteCertificates.ps1 -Scan `nor `n.\DeleteCertificates.ps1 -Scan -DeleteCerts
         -Scan : Scans for expired certificates to delete based on predefined certificate templates
         -DeleteCerts : Performs the deletion of certificates from the CA DB" "Error"
}

#*********** Main()***************** 
# Clear screen
Clear-Host


LogEvent "DeleteCertificates --> Started" "Information"
$numberOfArgs = $args.Count

if (($numberOfArgs -lt 1) -or ($numberOfArgs -gt 2))  # No parms defined
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
    
    # Determine if only "-DeleteCerts" is define.  If so then exit
    if (($enableDeleteCerts -eq $true) -and ($enableScan -eq $false)) 
    {
        Usage-Message
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
$stopwatch.stop()
$stopwatch

Remove-Item -Path C:\Users\wclement\Documents\TestScripts\*.txt
Remove-Item -Path C:\Users\wclement\Documents\TestScripts\*.log
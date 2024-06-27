[int]$pageLimit = 1000 # Number of certificates to retrieve per page
$certificateCollectionId = 0 #collectionId (use 0 if no ID is needed)
$apiEndpoint = "<command dns>/KeyfactorAPI" #no https://

#Basic Authentication Variables
$apiusername = '<domain\<username>'
$apipassword = "<password>"
$exportpath = "C:\Users\jhowland\Downloads\certs.csv"

function Get-CertificateChunkFromCollection()
{
	$apiURL = "$apiEndpoint/Certificates?collectionId=$certificateCollectionId&includeMetadata=true&pq.pageReturned=$pageNumber&pq.returnLimit=$pageLimit&pq.includeRevoked=false&pq.includeExpired=false"
	
	try
	{
        write-host "Getting Page: $pageNumber"
		$data = Invoke-WebRequest -Method GET -Uri $apiURL -Headers $headers -Credential $apiCredential
        return $data
	}
	catch
	{
		$_
		exit
	}
}
# Set Basic Auth API headers
$headers = @{
    'content-type'= 'application/json'
    "X-Keyfactor-Requested-With"= "APIClient"
    "x-keyfactor-api-version"="1.0"
}


# Retrieve all certificates
[int]$count = 0 # Count of certs retrieved
[int]$totalCount = 0 # Total amount of certs to retrieve
[int]$pageNumber = 1 # Current Page Number
[int]$totalPages = -1 # Total number of pages to retrieve
$apisecurepasswd = ConvertTo-SecureString $apipassword -AsPlainText -Force
$apiCredential = New-Object System.Management.Automation.PSCredential($apiusername, $apisecurepasswd)

while (($count -lt $totalCount) -or ($pageNumber -eq 1))
{
	$response = Get-CertificateChunkFromCollection -PageLimit $pageLimit -PageNumber $pageNumber -certificateCollectionId $certificateCollectionId
	
	if ($pageNumber -eq 1)
	{
		$totalCount = $response.Headers['x-total-count']
		$totalPages = [math]::ceiling($totalCount / $pageLimit)
	}
	$certs = $response.Content | ConvertFrom-Json
	
	foreach ($certitem in $certs) 
    {
        #makedate readable
        $from = $cert.NotBefore
        $from = $from.Split("T")[0]
        $from = ([DateTime]$from).ToString('MM-dd-yyyy')
        $to = $cert.NotAfter
        $to = $to.Split("T")[0]
        $to = ([DateTime]$to).ToString('MM-dd-yyyy')

        #figure days to expire
        $days = (NEW-TIMESPAN –Start $from –End $to).Days

        #gather sans
        $sans = New-Object System.Collections.Generic.List[System.Object] 
        foreach ($san in $cert.SubjectAltNameElements)
        {
            $sans.Add($san.value)
        }
        $sans = $sans -join ","

        $certificates = New-Object -TypeName PSObject
        $certificates | Add-Member -NotePropertyName "Common Name" -NotePropertyValue $certitem.IssuedDN
        $certificates | Add-Member -NotePropertyName "Valid From" -NotePropertyValue $from
        $certificates | Add-Member -NotePropertyName "Valid To" -NotePropertyValue $to
        $certificates | Add-Member -NotePropertyName "Days to Expiration" -NotePropertyValue $days
        $certificates | Add-Member -NotePropertyName "Signature Algorithm" -NotePropertyValue $certitem.SigningAlgorithm
        $certificates | Add-Member -NotePropertyName "Key Size" -NotePropertyValue $cert.KeySizeInBits
        $certificates | Add-Member -NotePropertyName "Serial Number" -NotePropertyValue $certitem.SerialNumber
        $certificates | Add-Member -NotePropertyName "DN" -NotePropertyValue $certitem.IssuedCN
        $certificates | Add-Member -NotePropertyName "Issuer DN" -NotePropertyValue $certitem.IssuedDN
        $certificates | Add-Member -NotePropertyName "User Name" -NotePropertyValue $certitem.RequesterName
        $certificates | Add-Member -NotePropertyName "Total SANs" -NotePropertyValue $certitem.SubjectAltNameElements.Count
        $certificates | Add-Member -NotePropertyName "SANs" -NotePropertyValue $sans
        $certificates | Add-Member -NotePropertyName "Template" -NotePropertyValue $certitem.TemplateName
        $certificates | Add-Member -NotePropertyName "Metadata1" -NotePropertyValue $certitem.Metadata.Contact
        $certificates | Add-Member -NotePropertyName "Metadata2" -NotePropertyValue $certitem.Metadata.Contact
        foreach ($item in $certificates)
        {
            $item | Export-Excel -path $exportpath -Append
        }
    }
	$count = $pageLimit * $pageNumber
    $pageNumber++

}

Write-Host "Script Complete"


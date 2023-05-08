<#
	.NOTES
	===========================================================================
	 Created on:   	5/7/2023 10:27 AM
	 Created by:   	Jeremy Howland
	 Organization: 	Keyfactor
	 Filename: Download_log.ps1
	 Tested on V10.2
	===========================================================================
	.DESCRIPTION
		This script is an exapmle on how to retrieve a audit log from a Keyfactor Command Instance.
		This will output a Comma Delimited Output of the log
		Varriable on lines: 20,21,22,49:
		$commanduser is a domain\user format
		$comandpassword is the password of the $commanduser
		$commandapiurl is the base API url of the Keyfactor Command instance.  example: "http://example.keyfactor.com/KeyfactorAPI/"
		$query is the unencoded search parameters for the audit log (this can take the query of the audit log from the UI)
#>
#variables
$commanduser = '<domain\user>'
$comandpassword = '<API Password>>'
$commandapiurl = 'https://<commandurl>/KeyfactorAPI/'
#import assemby needed to encode
Add-Type -AssemblyName System.Web
#auth encoding
$pair = "$($commanduser):$($comandpassword)"
$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

#headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Keyfactor-Requested-With", "XMLHttpRequest")
$headers.Add("Authorization", "Basic $base64AuthInfo")
$headers.Add("Content-Type", "application/json")

function get-auditlog($query)
{
	$query = [uri]::EscapeDataString($query)
	$url = $commandapiurl + "Audit/Download?pq.queryString=" + $query
	$log = Invoke-RestMethod $url -Headers $headers -Method get
	if ($log.count -lt 1)
	{
		throw "Can not connect to $commandapiurl"
	}
    return $log
}

Try
{
    $query = '<QUERY>'
    $log = get-auditlog -query $query
    $log
}
Catch
{
    $_
}

# Microsoft CA Cleanup Scripts
This repository contains example scripts for deleting certificate and request data out of a Microsoft CA database. 
These scripts will not compact the database, and that function will need to be done outside of theses example scripts. For more information, see: https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/the-case-of-the-enormous-ca-database/ba-p/398226

> Note: These resources are not officially supported by Keyfactor and are meant to serve only as examples.


## Delete Expired Certificates Script
This script is designed to delete expired certificates from the Microsoft CA database. The amount it deletes is based on the variable $AmountToDelete, which is set to 10000 records by default. This value was found to have the best balance of number of certificates deleted vs impact to the CA, though individual performance may vary; the use of this script may degrade the performance of the MSCA. 
### Usage
Case insensitive inputs.  The order of the parameters does not matter:
- -Scan : Scans for expired certificates to delete based on predefined certificate templates and creates a file in which populated certificates are ready to be deleted.
- -DeleteCerts : Performs the deletion of certificates from the CA DB

Retrieve certs to delete only: 
- .\DeleteCertificates_Expired.ps1 –scan

Perform deletes based on previously ran "–Scan" and deletes the certs based on the data in the “CertsToDelete.txt” file.  It will not rescan the CA DB.
- .\DeleteCertificates_Expired.ps1 –DeleteCerts

Scans the CA DB for expired certs then delete the certs:
- .\DeleteCertificates_Expired.ps1 –scan –DeleteCerts


## Delete Denied Certificates Script
This script is designed to delete denied certificates from the Microsoft CA database. This script will delete all denied certificate requests regardless of amount found.
### Usage
Case insensitive inputs.  The order of the parameters does not matter:
- -Scan : Scans for expired certificates to delete based on predefined certificate templates
- -Denied : Performs the deletion of denied certificate requests from the CA DB. This parameter is optional.
- -DeleteCerts : Performs the deletion of certificates from the CA DB

Retrieve certs to delete only 
- .\DeleteCertificates_Denied.ps1 –scan 

Perform deletes based on previously ran "–Scan" and deletes the certs based on the data in the “CertsToDelete.txt” file.  It will not rescan the CA DB.
- .\DeleteCertificates_Denied.ps1 –DeleteCerts

Scans the CA DB for denied cert requests then delete the requests.
- .\DeleteCertificates_Denied.ps1 –scan –Denied –DeleteCerts

Scans the CA DB for failed cert requests then deletes the requests.
- .\DeleteCertificates_Failed.ps1 –scan –DeleteCerts


## Delete Failed Certificates Script
This script is designed to delete failed certificates from the Microsoft CA database. This script will delete all failed certificate requests regardless of amount found.
### Usage
Case insensitive inputs.  The order of the parameters does not matter:
- -Scan : Scans for expired certificates to delete based on predefined certificate templates
- -Failed : Performs the deletion of denied certificate requests from the CA DB
- -DeleteCerts : Performs the deletion of certificates from the CA DB

Retrieve certs to delete only 
- .\DeleteCertificates_Failed.ps1 –scan 

Perform deletes based on previously ran "-Scan" and deletes the certs based on the data in the “CertsToDelete.txt” file.  It will not rescan the CA DB.
- .\DeleteCertificates_Failed.ps1 –DeleteCerts

Scans the CA DB for failed cert requests then delete the requests.
- .\DeleteCertificates_Failed.ps1 –scan –Failed –DeleteCerts

Scans the CA DB for failed cert requests then deletes the requests.
- .\DeleteCertificates_Failed.ps1 –scan –DeleteCerts

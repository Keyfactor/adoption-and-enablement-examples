# Full Extract Script
- tested on V10.5 but should work on newer versions that have basic auth enabled.
## Varibles Definittion
- [int]$pageLimit = Number of certificates to retrieve per page
- $certificateCollectionId = collectionId (use 0 if no ID is needed)
- $apiEndpoint = the DNS of the command server (example: "keyfactor.com/KeyfactorAPI")
- $apiusername = Username of the user or service account
- $apipassword = password of the user or service account
- $exportpath = location of where you want to export the csv file (example: "c:\temp\export.csv")

## Discription
This script will call the Keyfactor Command APi and pull all certificate data for the certificate defined in the CollectionID.  the data will be placed in a CSV file and exported to your local file system.  The format of the CSV is similar to the full extract report found in Keyfactor Command Reports.

## Pulling Metadata
editing or adding this line will add metadata to your csv.  the "Metadata1" can be whatever you want to name the column in the csv and Contact at the end of the $certitem.Metadata.Contact needs to be the name of the metadata field as Keyfactor Command knows it.
- $certificates | Add-Member -NotePropertyName "Metadata1" -NotePropertyValue $certitem.Metadata.Contact

> Note: These resources are not officially supported by Keyfactor and are meant to serve only as examples. 
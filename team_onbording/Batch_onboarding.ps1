# Description: This script is used to onboard multiple teams in Keyfactor using a CSV file.
# It reads the team names, emails, claims, and claim types from the CSV file and calls the Keyfactor onboarding script for each team.
foreach ($line in Import-Csv -Path $CSV_PATH) {
    .\keyfactor_onboarding.ps1 -enviroment Production -team_name $line.name -team_email $line.email -Claim $line.claim -Claim_Type $line.claimType
}
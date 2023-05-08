import requests
import json
import urllib.parse

"""
.NOTES
 Created on:   	5/7/2023 10:27 AM
 Created by:   	Jeremy Howland
 Organization: 	Keyfactor
 Filename: audit_log.py
 Tested on V10.2
.DESCRIPTION
 This script is an example on how to download a audit log from a Keyfactor Command Instance.
 This will output a Comma Delimited Output of the log
 Varriable on lines: 44,45,46,47:
 $commanduser is a domain backslash user format
 $comandpassword is the password of the $commanduser
 $commandapiurl is the base API url of the Keyfactor Command instance.  example: "http://example.keyfactor.com/KeyfactorAPI/"
 $query is the unencoded search parameters for the audit log (this can take the query of the audit log from the UI)
"""


HEADERS: dict = {
    'content-type': 'application/json',
    'accept': 'application/json',
    'x-keyfactor-requested-with': 'APIClient'
}


def getauditlog(commanduser, commandpass, commandurl, query):
    encquery = urllib.parse.quote(query)
    fullURL = f'{commandurl}/Audit/Download?pq.queryString={encquery}'
    print(fullURL)
    f = requests.get(fullURL, auth=(commanduser, commandpass), proxies=None, headers=HEADERS, verify=True)
    results = json.loads(f.content)
    if len(results) < 0:
        print("ERROR: error calling Command")
    else:
        return results


def main():
    commanduser = '<domain api User>'
    commandpass = '<API PASSWORD>'
    commandurl = 'https://<COMMAND url>/KeyfactorAPI/'
    query = '<QUERY>"'
    results = getauditlog(commanduser, commandpass, commandurl, query)
    print(results)


if __name__ == '__main__':
    main()

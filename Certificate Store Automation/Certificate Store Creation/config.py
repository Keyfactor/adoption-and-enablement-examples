KEYFACTOR_URLS: dict = {
    'dev': 'https://keyfactorurl.com/',
    'prod': 'https://keyfactorurl.com/'
}

KEYFACTOR_PASS: dict = {
    'dev': 'pass',
    'prod': 'pass'
}

KEYFACTOR_ID: dict = {
    'dev': 'domain\\user',
    'prod': 'domain\\user'
}

LDAP_CONTROLLER: dict = {
    '10.3.10.4': {
        'query': 'dc=domain,dc=local',
        'username': 'domain\\user',
        'password': 'pass' 
    }      
}

PROXY = None

HEADERS: dict = {
    'content-type': 'application/json',
    'accept': 'application/json',
    'x-keyfactor-requested-with': 'APIClient'
}

WINDOWS_EXTENSIONS: dict = {
    'PEM-SSH': 'pem,crt,cert',
    'JKS-SSH': 'jks,noext'
}

LINUX_EXTENSIONS: dict = {
    'PEM-SSH': 'pem,cer,crt',
    'JKS-SSH': 'jks,keystore,ks,cacerts'
}

F5_LIST: list = [
    'F5-SL-REST',
    'F5-CA-REST'
]
OTHER_LIST: list = [
    'JKS-SSH',
    'PEM-SSH'
]

#Based on TZ Database
CURRENT_TZ = 'US/Eastern'

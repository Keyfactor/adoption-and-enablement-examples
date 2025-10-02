$script:Variables = @{
    KEYFACTOR_HOSTNAME  = "customer.keyfactorurl.com"
    KEYFACTOR_API_PATH  = "/KeyfactorAPI"
    client_id           = ''
    client_secret       = ''
    token_url           = ""
    scope               = ''
    audience            = ''
    SelectedStoreType   = "Akamai,RFPEM" #Comma separated list of store types to create
    KFUTIL_EXP          = 0
    KFUTIL_DEBUG        = 0
    skip_verify         = $true
}


$env:KEYFACTOR_AUTH_CLIENT_ID = $Variables.client_id
$env:KEYFACTOR_AUTH_CLIENT_SECRET = $Variables.client_secret
$env:KEYFACTOR_AUTH_TOKEN_URL = $Variables.token_url
$env:KEYFACTOR_AUTH_SCOPES = $Variables.scope
$env:KEYFACTOR_AUTH_AUDIENCE = $Variables.audience
$env:KEYFACTOR_HOSTNAME = $Variables.KEYFACTOR_HOSTNAME
$env:KEYFACTOR_SKIP_VERIFY = $Variables.skip_verify
$env:KEYFACTOR_API_PATH = $Variables.KEYFACTOR_API_PATH
$env:KFUTIL_EXP = $Variables.KFUTIL_EXP
$env:KFUTIL_DEBUG = $Variables.KFUTIL_DEBUG

$newstores = $variables.SelectedStoreType -split ','
foreach ($item in $newstores)
{
    kfutil store-types create -n $item
}


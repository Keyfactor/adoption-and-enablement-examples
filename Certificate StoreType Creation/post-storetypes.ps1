# ----------------------------
# Configuration
# ----------------------------
$Config = @{
    KEYFACTOR_HOSTNAME = "customer.customerpki.com"
    KEYFACTOR_API_PATH = "/KeyfactorAPI"
    KFUTIL_EXP         = 0
    KFUTIL_DEBUG       = 0
    KEYFACTOR_SKIP_VERIFY = $true

    KEYFACTOR_AUTH_CLIENT_ID     = ''
    KEYFACTOR_AUTH_CLIENT_SECRET = ''
    KEYFACTOR_AUTH_TOKEN_URL     = ""
    KEYFACTOR_AUTH_SCOPES        = ''
    KEYFACTOR_AUTH_AUDIENCE      = ''

    SelectedStoreType = @("WinSql", "vCenter") # comma-separated if needed
}

# ----------------------------
# Set Environment Variables
# ----------------------------

foreach ($key in $Config.Keys) {
    if ($key -ne 'SelectedStoreType') {
        Set-Item -Path "Env:$key" -Value ([string]$Config[$key])
    }
}


# ----------------------------
# Process Store Types
# ----------------------------
$storeTypes = $Config.SelectedStoreType -split ',' | ForEach-Object {
    $_.Trim()
} | Where-Object { $_ -ne '' }

foreach ($store in $storeTypes) {
    try {
        Write-Host "Creating store type: $store"
        kfutil store-types create -n $store
    }
    catch {
        Write-Error "Failed to create store type $store : $_"
    }
}
# Purpose: This script loads the variables used by the other scripts in the team onboarding process
$script:Variables = @{
    COLLECTION_DESCRIPTION   = ""
    ROLE_DESCRIPTION         = "T"
    CLAIM_SCHEME             = ""
    CLAIM_DESCRIPTION        = ""
    INCLUDE_EMAIL_IN_ROLE   = $false
    CLIENT_ID       = ''
    CLIENT_SECRET   = ''
    TOKEN_URL       = ''
    SCOPE           = ''
    KEYFACTORAPI    = ''
    ADDITIONAL_COLLECTIONS = @{
        1 = ""
        2 = ""
        3 = ""
    }
    ADDITIONAL_ROLES = @{
        1 = ""
        2 = ""
    }
    ROLE_PERMISSIONS = @{
        1 = "/portal/read/"
        2 = "/certificates/collections/revoke/"
        3 = "/certificates/collections/private_key/read/"
        4 = "/certificates/collections/metadata/modify/"
        5 = "/certificates/collections/change_owner/"
        6 = "/certificates/collections/read/"
    }
}

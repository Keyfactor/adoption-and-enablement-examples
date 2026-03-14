import logging
import requests
import json
import time
import sys
import automationassets



environment = automationassets.get_automation_variable("environment").lower()
log_level_name = automationassets.get_automation_variable("log_level").upper()
log_level = getattr(logging, log_level_name, logging.INFO)

#Logging
global logger
logger = logging.getLogger(environment)
logger.setLevel(log_level)
logger.propagate = False
if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
logger.propagate = False


def load_variables():
    """
    Load configuration values, using Key Vault when vault_uri is configured,
    otherwise using client-secret from Automation variables.
    """
    secret_location = automationassets.get_automation_variable("secret_location").lower()
    logger.info(f"Loading configuration from {secret_location}")
    if secret_location == "vault":
        logger.info("vault_uri is configured, attempting to load secrets from Key Vault.")
        from azure.keyvault.secrets import SecretClient
        from azure.identity import ManagedIdentityCredential
        vault_uri = automationassets.get_automation_variable("vault_uri")
        credential = ManagedIdentityCredential()
        kv_client = SecretClient(vault_url=vault_uri, credential=credential)
        client_secret = (kv_client.get_secret("client-secret").value).lower()
    elif secret_location == "automation":
        logger.info("vault_uri is not configured, falling back to client-secret from automation variable.")
        client_secret = automationassets.get_automation_variable("client-secret")

    return {
        "client_id": automationassets.get_automation_variable("client_id"),
        "client_secret": client_secret,
        "token_url": automationassets.get_automation_variable("token_url"),
        "scope": automationassets.get_automation_variable("scope"),
        "audience": automationassets.get_automation_variable("audience"),
        "keyfactordns": automationassets.get_automation_variable("keyfactor_base_url"),
        "scheme": automationassets.get_automation_variable("idp_scheme"),
        "entra_all_users_group": automationassets.get_automation_variable("parent_group")
    }


def create_entra_auth_headers():
    try:
        token_resp = requests.post(
        variables["token_url"],
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "client_credentials",
            "client_id": variables["client_id"],
            "client_secret": variables["client_secret"],
            "scope": "https://graph.microsoft.com/.default"
        },
        timeout=30
        )
        token_resp.raise_for_status()
        token = token_resp.json()["access_token"]
        logger.debug(f"Obtained access token for Microsoft Graph API: {token[:20]}...")  # Print only the beginning of the token for security
        if token:
            logger.debug(f"Obtained access token for Microsoft Graph API: {token[:20]}...")  # Log only the beginning of the token for security
        else:
            logger.error("Failed to obtain access token for Microsoft Graph API")
            raise Exception("Failed to obtain access token for Microsoft Graph API")
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
    except requests.exceptions.RequestException as e:
        logger.error(f"Error obtaining access token for Microsoft Graph API: {e}")
        raise


class KeyfactorClient:
    """
    Client for interacting with the Keyfactor API.

    This class provides methods for making HTTP requests to the Keyfactor API,
    including GET, POST, and PUT requests. It manages the session state and
    handles the construction of the full URLs for API endpoints. The class is
    intended to streamline communication with the Keyfactor service by providing
    a centralized client instance.

    :ivar vars: Dictionary of configuration variables required for API communication.
                It should include the base URL under the key 'keyfactordns'.
    :type vars: dict
    """

    def __init__(self, retries: int = 1, backoff: int = 3):
        self.vars = variables
        self.session = requests.Session()
        self.retries = retries
        self.backoff = backoff

    def _get_access_token(self):
        token_resp = requests.post(
        self.vars["token_url"],
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "client_credentials",
            "client_id": self.vars["client_id"],
            "client_secret": self.vars["client_secret"],
            **({"scope": self.vars["scope"]} if self.vars.get("scope") else {}),
            **({"audience": self.vars["audience"]} if self.vars.get("audience") else {}),
        },
        timeout=30
        )
        token_resp.raise_for_status()
        access_token = token_resp.json()["access_token"]
        return access_token


    def _create_auth_headers(self, header_version: int):
        return {
            "content-type": "application/json",
            "accept": "text/plain",
            "x-keyfactor-requested-with": "APIClient",
            "x-keyfactor-api-version": f"{header_version}.0",
            "Authorization": f"Bearer {self._get_access_token()}",
        }
    # Helper to build full URL from base and endpoint
    def _build_url(self, endpoint: str) -> str:
        base = self.vars["keyfactordns"].rstrip("/")
        return f"{base}/{endpoint.lstrip('/')}"

    # helper to allow & in value for api call
    def _check_name(self, name: str):
        if '&' in name:
            name =  name.replace('&', '%26')
        return name

    def _request_with_retry(self, method: str, url: str, **kwargs):
        last_exception = None
        for attempt in range(1, self.retries + 1):
            try:
                logger.debug(f"Attempt {attempt}: {method.upper()} {url}")
                resp = self.session.request(method, url, timeout=60, **kwargs)
                resp.raise_for_status()
                return resp
            except requests.RequestException as e:
                logger.warning(f"Attempt {attempt} failed: {e}")
                last_exception = e
                if attempt < self.retries:
                    time.sleep(self.backoff)
        raise last_exception

    def get(self, endpoint: str, header_version: int = 1):
        headers = self._create_auth_headers(header_version)
        url = self._build_url(endpoint)
        return self._request_with_retry("get", url, headers=headers)

    def post(self, endpoint: str, body: dict, header_version: int = 1):
        headers = self._create_auth_headers(header_version)
        url = self._build_url(endpoint)
        return self._request_with_retry("post", url, headers=headers, data=json.dumps(body))

    def put(self, endpoint: str, body: dict, header_version: int = 1):
        headers = self._create_auth_headers(header_version)
        url = self._build_url(endpoint)
        return self._request_with_retry("put", url, headers=headers, data=json.dumps(body))

    def role_get(self, name: str, header_version: int = 2):
        name = self._check_name(name)
        endpoint = f"Security/Roles?QueryString=Name%20-eq%20%22{name}%22"
        return (self.get(endpoint, header_version)).json()

    def role_id_get(self, id: str, header_version: int = 2):
        endpoint = f"Security/Roles/{id}"
        return (self.get(endpoint, header_version)).json()

    def role_create_post(self, body: dict, header_version: int = 2):
        endpoint = f"Security/Roles"
        return (self.post(endpoint, body, header_version)).json()

    def role_update_put(self, body: dict, header_version: int = 2):
        endpoint = f"Security/Roles"
        return (self.put(endpoint, body, header_version)).json()

    def collection_name_get(self, name: str, header_version: int = 1):
        name = self._check_name(name)
        endpoint = f"CertificateCollections?QueryString=Name%20-eq%20%22{name}%22"
        return (self.get(endpoint, header_version)).json()

    def collection_create_post(self, body: dict, header_version: int = 1):
        endpoint = f"CertificateCollections"
        return (self.post(endpoint, body, header_version)).json()

    def permissionset_name_get(self, name: str, header_version: int = 1):
        name = self._check_name(name)
        endpoint = f"PermissionSets?QueryString=Name%20-eq%20%22{name}%22"
        return (self.get(endpoint, header_version)).json()

    def claims_create_post(self, body: dict, header_version: int = 1):
        endpoint = f"Security/Claims"
        return (self.post(endpoint, body, header_version)).json()


def to_lower(obj):
    """Recursively convert all strings in JSON-like structures to lowercase."""
    if isinstance(obj, dict):
        return {str(k).lower(): to_lower(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [to_lower(item) for item in obj]
    elif isinstance(obj, str):
        return obj.lower()
    else:
        return obj


def get_graph_transitive_members(group_name: str) -> list:
    """
    Retrieve a list of transitive members (group names) for a specified Azure AD group.

    This function connects to Microsoft Graph API to retrieve the transitive group members for a
    specific Azure AD group using the group name. The function performs the following steps:
    1. Authenticates with the Microsoft Graph API using client credentials.
    2. Searches for the target group by its display name.
    3. Fetches the transitive members for the group and filters for groups.
    4. Collects the `displayName` values of the transitive group members.
    5. Converts the group names to lowercase and returns the list.

    The function returns an empty list if the group is not found or if an error occurs during the process.

    :param group_name: The display name of the Azure AD group to fetch the transitive members for.
    :type group_name: str
    :return: List containing the display names of the transitive group members in lowercase.
    :rtype: list
    """
    logger.info(f"Getting transitive members for group '{group_name}'")
    try:
        headers = create_entra_auth_headers()
        logger.info(f"Using authentication headers: {headers}")
        search_url = f"https://graph.microsoft.com/v1.0/groups?$filter=displayName eq '{group_name}'"
        search_resp = requests.get(search_url, headers=headers, timeout=30)
        search_resp.raise_for_status()
        search_data = search_resp.json()
        if search_data.get("value"):
            logger.debug(f"GET {search_resp.status_code} - {search_url} - Retrieved {len(search_data.get('value', []))} groups")
        if not search_data.get("value"):
            logger.warning(f"Group '{group_name}' not found")
            return []
        group_id = search_data["value"][0]["id"]
        members_url = (f"https://graph.microsoft.com/v1.0/groups/{group_id}/transitiveMembers/microsoft.graph.group"
                       f"?$select=displayName")
        groups = []
        while members_url:
            members_resp = requests.get(members_url, headers=headers, timeout=30)
            members_resp.raise_for_status()
            members_data = members_resp.json()
            group_members = [
                item["displayName"]
                for i, item in enumerate(members_data.get("value", []))
                if isinstance(item, dict) and item.get("displayName") is not None
                   or logger.warning(f"value[{i}] missing 'displayName' key: {item}") is None
            ]
            logger.debug(f"GET {members_resp.status_code} - {members_url} - Retrieved {len(group_members)} members")
            groups.extend(group_members)
            members_url = members_data.get("@odata.nextLink")
        logger.info(f"Total groups to evaluate: {len(groups)}")
        groups = list(map(str.lower, groups))
        return groups

    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching transitive group members from Entra for group '{group_name}': {e}")
        return []


def build_oauth_claim(member_name: str):
    """
    Builds an OAuth claim for the given member name.

    This function generates a new OAuth claim using a specific authentication
    scheme and assigns attributes like claimtype, claimvalue, and description
    based on the provided member name. The process is logged for debugging
    purposes.

    :param member_name: The name of the member for whom the OAuth claim is being created.
    :type member_name: str
    :return: A dictionary representing the new OAuth claim with attributes such as
        claimtype, claimvalue, providerauthenticationscheme, and description.
    :rtype: dict
    """
    logger.debug(f"building oauth claim for role")
    new_claim = {
        "claimtype": 4,
        "claimvalue": member_name,
        "providerauthenticationscheme": variables["scheme"],
        "description": member_name
    }
    logger.debug(f"new claim: {new_claim}")
    return new_claim


def claims_check(role, member_name):
    """
    Checks if claims exist in the role data and verifies if a member name matches
    specific claim criteria.

    This function inspects the claims in the provided role dictionary to determine
    if the given member is associated with an 'oauthrole' type claim. If a claim of
    type 'oauthrole' is found, it further checks if the member name matches the
    value associated with this claim type. Depending on the conditions, it returns
    a boolean value indicating the result.

    :param role: A dictionary object representing a role, potentially containing
        claim information within its 'Claims' key.
    :type role: dict
    :param member_name: The name of the member to be checked against the
        claims in the given role.
    :type member_name: str
    :return: Returns True if either the role has no claims or the member name
        does not match a claim of type 'oauthrole'. Otherwise, returns False.
    :rtype: bool
    """
    logger.info("Checking if claims are in role data")
    if role.get('Claims') is None or role.get('Claims') == []:
        logger.debug(f"Role has no claims: {role.get('Claims')}")
        return True

    for claim in role.get('Claims'):
        claim = to_lower(claim)
        member_name = member_name.lower()
        if claim.get('claimtype') == 'oauthrole' and member_name in claim.get('claimvalue', ''):
            return False
    return True


def rebuild_claims(role, new_claim = None):
    """
    Rebuilds and updates the claims of a role. It processes each claim, applies any
    necessary transformations, and incorporates an optional new claim if provided.

    :param role: A dictionary representing the role that contains a list of claims
                 under the 'Claims' key.
    :type role: dict
    :param new_claim: An optional new claim to be added to the role's claims.
                      Defaults to None.
    :type new_claim: dict, optional
    :return: The updated role with rebuilt claims.
    :rtype: dict
    """
    logger.info("Rebuilding Claims to update Role")
    existing_claims = []
    for claim in role['Claims']:
        claim = build_claim(claim)
        existing_claims.append(claim)
    if new_claim is not None:
        new_claim = build_claim(new_claim)
        existing_claims.append(new_claim)
    role['Claims'] = existing_claims
    logger.debug(f"Role Claims: {role.get('Claims')}")
    return role


def build_claim(claim) -> dict:
    """
    Builds and validates a new claim object based on the given claim input. The function maps the
    claim type to a numeric value, validates its type, and determines the appropriate authentication
    scheme based on the claim type.

    :param claim: The claim dictionary to be processed. Must include details such as "claimtype"
                  and optionally "claimvalue", "provider", and "description".
    :type claim: dict
    :return: A dictionary representing the newly constructed claim with fields such as
             "claimType", "claimValue", "providerAuthenticationScheme", and "description".
    :rtype: dict
    :raises ValueError: If the input claim is None.
    :raises TypeError: If the input claim is not a dictionary.
    :raises RuntimeError: If the claim type (either as a string or a number) is unknown or invalid.
    """
    logger.info("Building Claim")
    try:
        if claim is None:
            raise ValueError("Claim cannot be None")
        if not isinstance(claim, dict):
            raise TypeError(f"Claim must be a dictionary, got {type(claim)}")
    except ValueError as ve:
        logger.error(f"Invalid claim: {ve}")
        logger.debug("Leaving build claim")

    CLAIM_TYPE_MAP = {
        "user": 0,
        "group": 1,
        "computer": 2,
        "oauthoid": 3,
        "oauthrole": 4,
        "oauthsubject": 5,
        "oauthclientId": 6,
    }
    claim = to_lower(claim)

    ct = claim.get("claimtype")

    # Handle case where ClaimType is already a number
    if isinstance(ct, int):
        # Validate it's a known claim type number
        if ct not in CLAIM_TYPE_MAP.values():
            raise RuntimeError(f"Unknown claim type number: {ct}")
        claim_type_num = ct
    elif ct in CLAIM_TYPE_MAP:
        # ClaimType is a string, map it to number
        claim_type_num = CLAIM_TYPE_MAP[ct]
    else:
        logger.debug(f"ClaimType is a number: {ct}")
        logger.debug(f"ClaimType is a number: {claim}")
        raise RuntimeError(f"Unknown claim type: {ct}")

    provider = claim.get("provider") or {}
    oauth_claim_numbers = [3, 4, 5, 6]
    ad_claim_numbers = [0, 1, 2]
    if claim_type_num in oauth_claim_numbers:
        provider = {"authenticationscheme": variables["scheme"]}
    elif claim_type_num in ad_claim_numbers:
        provider = {"authenticationscheme": "Active Directory"}
    new_claim = {
        "claimType": claim_type_num,
        "claimValue": claim.get("claimvalue"),
        "providerAuthenticationScheme": provider.get("authenticationscheme"),
        "description": claim.get("description"),
    }
    logger.debug(f"new claim: {new_claim}")
    return new_claim


def build_new_role(member_name):
    logger.info("Creating New Role")
    data = {
        "name": member_name,
        "description": member_name,
        "emailaddress": "",
        "permissionSetid": (client.permissionset_name_get('global'))[0]['Id'],
        "EnableCertOwnership": True,
        "permissions": [ ],
        "claims": [
            {
                "claimtype": 4,
                "claimvalue": member_name,
                "providerauthenticationscheme": variables["scheme"],
                "description": member_name
            }
        ]
    }
    new_role = client.role_create_post(data)
    logger.debug(f"Data Returned from API: {new_role}")
    return new_role


def process_work(role_needed, oauth_claim_needed, member_name, role=None):
    if not role_needed:
        if oauth_claim_needed:
            new_claim = build_oauth_claim(member_name)
            role = rebuild_claims(role, new_claim)

        if 'Immutable' in role:
            del role['Immutable']

        role = rebuild_claims(role)
        logger.debug(msg=f"New Role Data: {role}")
        role['EnableCertOwnership'] = True
        return client.role_update_put(role)

    if role_needed:
        role =  build_new_role(member_name)
        return role


def main():
    global variables
    global client
    variables = load_variables()
    logger.info(f"Starting Script for environment: {environment}")
    logger.info(f"Gathering all members of {variables['entra_all_users_group']} from gragh API's")
    client = KeyfactorClient()
    entra_members = get_graph_transitive_members(variables["entra_all_users_group"])
    for member_name in entra_members:
        try:
            logger.info(f"Starting to process member: {member_name}")
            logger.info(f"Getting role for: {member_name}")
            role = client.role_get(member_name)
            role_needed = not role
            if role_needed:
                logger.info(f"Role not found for: {member_name}, creating new role.")
                logger.info(f"Checking if claim is in keyfactor")
                oauth_claim_needed, role_needed = True, True
                logger.info(f"role needs created: {role_needed}")
                logger.info(f"claim needs created: {oauth_claim_needed}")
                process_work(role_needed, oauth_claim_needed, member_name)
            else:
                logger.info(f"Role found for: {member_name}, creating new role.")
                complete_role = (client.role_id_get(role[0]['Id']))
                logger.debug(f"Role Data: {complete_role}")
                logger.info(f"Checking if claim is in keyfactor")
                oauth_claim_needed = claims_check(complete_role, member_name)
                logger.debug(f"claim needs created: {oauth_claim_needed}")
                if oauth_claim_needed:
                    process_work(role_needed, oauth_claim_needed, member_name, complete_role)
                else:
                    logger.info(f"Role is complete, Nothing to do for: {member_name}")
        except Exception as e:
            logger.error(f"An error occurred while processing member '{member_name}': {e}")
            continue

    logger.info("Script Finished. Exiting.")


if __name__ == "__main__":
    main()

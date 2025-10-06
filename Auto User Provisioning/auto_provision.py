import logging
import math
import requests
import json
import urllib3
from datetime import datetime, timedelta
import os
import glob

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

dry_run = True
environment = 'Test'
log_retention_days = 30
proxies = {
    # 'http': 'http://127.0.0.1:7890',
    # 'https': 'http://127.0.0.1:7890'
}

def load_variables(environment='Test'):  # Default to Test environment
    """
    Loads environment-specific variables into a global `variables` dictionary. The function
    uses the provided environment name to set global configuration values necessary for
    authentication and service communication.

    :param environment: A string representing the environment name. This specifies the
        configuration to load. Defaults to 'Test'. Accepted values are 'Test' and
        'Production'.
    :type environment: str
    :return: None
    """
    global variables
    if environment == 'Production':
        variables = {
            'entra_client_id': '',
            'entra_client_secret': '',
            'entra_token_url': '',
            'client_id': '',
            'client_secret': '',
            'token_url': '',
            'scope': '',
            'audience': '',
            'keyfactordns': '',
            'scheme': '',
            'entra_all_users_group': '',
            'MODULE_LOGGER_NAME': "prod_provisioning"
        }
    elif environment == 'Test':
        variables = {
            'entra_client_id': '',
            'entra_client_secret': '',
            'entra_token_url': '',
            'client_id': '',
            'client_secret': '',
            'token_url': '',
            'scope': '',
            'audience': '',
            'keyfactordns': '',
            'scheme': 'Entra',
            'entra_all_users_group': '',
            'MODULE_LOGGER_NAME': "test_provisioning"
        }

def clean_old_error_logs(days=log_retention_days):
    """
    Deletes old error log files created prior to a specified number of days. This function searches
    for log files in the current directory matching the naming pattern "error_log_*.log". Files
    older than the cutoff date are deleted to free up space and maintain organization.

    :param days: The number of days to retain error log files. Files older than the specified
        number of days will be removed.
    :type days: int
    :return: None
    """
    try:
        cutoff_date = datetime.now() - timedelta(days=days)
        log_pattern = "error_log_*.log"

        for log_file in glob.glob(log_pattern):
            try:
                # Get file modification time
                file_time = datetime.fromtimestamp(os.path.getmtime(log_file))

                if file_time < cutoff_date:
                    os.remove(log_file)
                    print(f"Deleted old error log: {log_file}")
            except Exception as e:
                print(f"Error deleting {log_file}: {e}")
    except Exception as e:
        print(f"Error cleaning old error logs: {e}")

def get_logger() -> logging.Logger:
    """
    Configures and returns a logger instance for the application. The logger is
    configured with a console handler for all logs and a file handler for error
    logs only. If the logger has existing handlers, no configuration is applied.
    Older error logs are cleaned up before configuring new handlers.

    :return: A logging.Logger instance with appropriate handlers and configurations.
    :rtype: logging.Logger
    """
    logger = logging.getLogger(variables["MODULE_LOGGER_NAME"])
    if not logger.handlers:
        # Clean old error logs before setting up new handler
        clean_old_error_logs(days=30)

        # Console handler for all logs
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(name)s - %(message)s"))
        logger.addHandler(console_handler)

        # File handler for error logs only
        date_str = datetime.now().strftime("%Y%m%d")
        file_handler = logging.FileHandler(f"provisioning_log_{date_str}.log")
        file_handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(name)s - %(message)s"))
        logger.addHandler(file_handler)

        logger.setLevel(logging.INFO)
        logger.propagate = False
    return logger

def create_auth_headers(header_version: int):
    """
    Creates authentication headers necessary for API requests by retrieving an access token
    using the specified client credentials and constructing a header with required fields.

    :param header_version: An integer representing the API version to be included in the headers.
    :return: A dictionary containing the authentication headers needed for API access.
    """
    token_resp = requests.post(
        variables["token_url"],
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "client_credentials",
            "client_id": variables["client_id"],
            "client_secret": variables["client_secret"],
            **({"scope": variables["scope"]} if variables.get("scope") else {}),
            **({"audience": variables["audience"]} if variables.get("audience") else {}),
        },
        timeout=30,
    )
    token_resp.raise_for_status()
    access_token = token_resp.json()["access_token"]
    return {
        "content-type": "application/json",
        "accept": "text/plain",
        "x-keyfactor-requested-with": "APIClient",
        "x-keyfactor-api-version": f"{header_version}.0",
        "Authorization": f"Bearer {access_token}",
    }

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
    def __init__(self, variables: dict):
        self.vars = variables
        self.session = requests.Session()

    # Helper to build full URL from base and endpoint
    def _build_url(self, endpoint: str) -> str:
        base = self.vars["keyfactordns"].rstrip("/")
        return f"{base}/{endpoint.lstrip('/')}"

    def get(self, endpoint: str, header_version: int = 1):
        # Refresh API version header per-call
        headers = create_auth_headers(header_version)
        url = self._build_url(endpoint)
        logger.debug(f"GET {url}")
        resp = self.session.get(url, headers=headers, timeout=60, proxies=proxies, verify=False)
        resp.raise_for_status()
        return resp

    def post(self, endpoint: str, body: dict, header_version: int = 1):
        headers = create_auth_headers(header_version)
        url = self._build_url(endpoint)
        resp = self.session.post(url, headers=headers, data=json.dumps(body), timeout=60, verify=False)
        resp.raise_for_status()
        return resp

    def put(self, endpoint: str, body: dict, header_version: int = 1):
        headers = create_auth_headers(header_version)
        url = self._build_url(endpoint)
        resp = self.session.put(url, headers=headers, data=json.dumps(body), timeout=60, verify=False)
        resp.raise_for_status()
        return resp

def get_graph_transitive_members(group_name: str) -> list:
    """
    Fetch the transitive members (sub-groups) of a specified group from Microsoft Entra using the Microsoft Graph API.
    This function retrieves all nested group members associated with the provided group name.

    Errors during the API request or response handling are logged, and an empty list is returned in case of an
    error.

    :param group_name: Name of the group to fetch transitive members for
    :type group_name: str
    :return: List of transitive group members, specifically groups, found under the given group
    :rtype: list
    """
    try:
        token_resp = requests.post(
            variables["entra_token_url"],
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "client_credentials",
                "client_id": variables["entra_client_id"],
                "client_secret": variables["entra_client_secret"],
                "scope": "https://graph.microsoft.com/.default"
            },
            timeout=30,
        )
        token_resp.raise_for_status()
        access_token = token_resp.json()["access_token"]
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        search_url = f"https://graph.microsoft.com/v1.0/groups?$filter=displayName eq '{group_name}'"
        search_resp = requests.get(search_url, headers=headers, timeout=30, proxies=proxies, verify=False)
        search_resp.raise_for_status()
        search_data = search_resp.json()
        if not search_data.get("value"):
            logger.warning(f"Group '{group_name}' not found")
            return []
        group_id = search_data["value"][0]["id"]
        groups = []
        members_url = f"https://graph.microsoft.com/v1.0/groups/{group_id}/transitiveMembers"
        while members_url:
            members_resp = requests.get(members_url, headers=headers, timeout=30, proxies=proxies, verify=False)
            logger.debug(
                f"GET {members_url} - {members_resp.status_code} - {members_resp.text}"
            )
            members_resp.raise_for_status()
            members_data = members_resp.json()
            group_members = [m for m in members_data.get("value", []) if
                             m.get("@odata.type") == "#microsoft.graph.group"]
            groups.extend(group_members)
            members_url = members_data.get("@odata.nextLink")
        logger.info(f"Total transitive group members retrieved: {len(groups)}")
        return groups
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching transitive group members from Entra for group '{group_name}': {e}")
        return []

def get_roles():
    """
    Fetches all roles from the Keyfactor API.

    This function retrieves roles in batches of 100 and combines them into a single
    list if the total number of roles exceeds 100. The number of pages required to
    retrieve all roles is calculated based on the `x-total-count` header from the
    initial API response.

    :return: A list of roles if the API call is successful and the roles are fetched.
             Returns ``False`` if the `x-total-count` header is missing or if there
             is an error during the API call.
    :rtype: list | bool

    :raises requests.exceptions.RequestException: Raised if there is an issue
         with the HTTP request to the Keyfactor API.
    """
    try:
        client = KeyfactorClient(variables)
        base_path = f"Security/Roles?returnlimit=100"
        response = client.get(base_path, header_version=2)
        total_count_header = response.headers.get("x-total-count")
        if total_count_header is None:
            return False
        total_count = int(total_count_header)
        logger.info(f"Total count of roles to process: {total_count}")
        roles = response.json()
        if total_count <= 100:
            return roles
        pages = math.ceil(total_count / 100)
        for page in range(2, pages + 1):
            f"{base_path}&PageReturned={page}"
            resp = client.get(base_path, header_version=2)
            roles.extend(resp.json())
        return roles
    except requests.exceptions.RequestException as e:
        logger.error(msg="Coult not get roles from Keyfactor API")
        logger.error(msg=f"get roles: {e}")
        return False

def get_claims():
    """
    Fetches claim data from the Keyfactor API.

    This function communicates with the Keyfactor API using the KeyfactorClient to
    retrieve the claims available. It employs pagination if the total number of
    claims exceeds the specified page size (100). Logs the process and total count
    of claims retrieved. If an exception occurs during the request, the function
    logs the error details and returns ``False``.

    :return: A list of claims retrieved from the API or ``False`` if the operation
             fails.
    :rtype: list | bool

    :raises requests.exceptions.RequestException: If an HTTP request to Keyfactor API fails.
    """
    try:
        client = KeyfactorClient(variables)
        base_path = f"Security/Claims?QueryString=ClaimType%20-eq%20%224%22&ReturnLimit=100"
        response = client.get(base_path, header_version=1,)
        total_count_header = response.headers.get("x-total-count")
        if total_count_header is None:
            return False
        total_count = int(total_count_header)
        logger.info(f"Total count of claims to process: {total_count}")
        claims = response.json()
        if total_count <= 100:
            return claims
        pages = math.ceil(total_count / 100)
        for page in range(2, pages + 1):
            f"{base_path}&PageReturned={page}"
            resp = client.get(base_path, header_version=2)
            claims.extend(resp.json())
        return claims
    except requests.exceptions.RequestException as e:
        logger.error(msg="Coult not get claims from Keyfactor API")
        logger.error(msg=f"get claims: {e}")
        return False

def create_claim(name, dry_run=False):
    """
    Creates an OAuth role-based claim in the Keyfactor system.

    This function validates if claim creation is necessary, constructs the
    appropriate payload, sends a request using the KeyfactorClient to create
    the claim, and handles any exceptions that may arise during the process.

    :param name: The name of the OAuth claim to be created.
    :type name: str
    :param dry_run: If True, simulates the claim creation without actually sending
                    any requests to the server.
    :type dry_run: bool
    :return: The JSON response from the Keyfactor server on successful creation,
             or False if an error occurs or the operation is skipped due to
             dry_run or other conditions.
    :rtype: dict or bool
    """
    if not should_create(name, dry_run):
        return
    try:
        client = KeyfactorClient(variables)
        data = {
            "ClaimType": "OAuthRole",
            "ClaimValue": name,
            "ProviderAuthenticationScheme": variables["scheme"],
            "Description": name
        }
        response = client.post("Security/Claims", body=data, header_version=1)
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(msg=f"Could not create claim for: {name}")
        logger.error(msg=f"creating claim: {e}")
        return False

def get_permission_set(name):
    """
    Retrieves the ID of a permission set by its name from the Keyfactor system.

    The function connects to the KeyfactorClient and queries for the permission
    set specified by the given name. If the permission set exists and matches the
    given name, its ID will be returned. If the permission set cannot be found,
    or if any error occurs during the process, the function returns False.

    :param name: The name of the permission set to retrieve.
    :type name: str
    :return: The ID of the permission set if found, or False otherwise.
    :rtype: int or bool
    """
    try:
        client = KeyfactorClient(variables)
        base_path = f"PermissionSets?QueryString=Name%20-eq%20%22{name}%22"
        response = client.get(base_path, header_version=1)
        total_count_header = response.headers.get("x-total-count")
        if total_count_header is None:
            return False
        data = response.json()
        for set in data:
            if set.get('Name') == name:
                return set.get('Id')
            else:
                return False
    except requests.exceptions.RequestException as e:
        logger.error(msg=f"Could not get permission set for: {name}")
        logger.error(msg=f"get permission set: {e}")
        return False

def create_role(name, claim, dry_run=False):
    """
    Creates a new role in the system by interacting with the security API. The role is defined
    by the provided name, claim information, and optional dry-run parameter. If the operation
    is executed successfully, the response from the API call is returned as a JSON object.
    Otherwise, in case of an error, the operation logs the details and returns False.

    :param name: The name of the role to be created
    :type name: str
    :param claim: A dictionary containing claim details such as `ClaimValue`, `Provider`
        information, and `Description` of the claim
    :type claim: dict
    :param dry_run: A boolean flag that, if set to True, ensures no changes are made in the
        actual system. Defaults to False
    :type dry_run: bool
    :return: A JSON object containing the API response if the role creation is successful,
        or False if an error occurs
    :rtype: dict or bool
    """
    if not should_create(name, dry_run):
        return

    try:
        client = KeyfactorClient(variables)
        data = {
            "Name": name,
            "Description": name,
            "EmailAddress": "",
            "PermissionSetId": get_permission_set('Global'),
            "Permissions": [
                '/portal/read/'
            ],
            "Claims": [
                {
                    "ClaimType": 4,
                    "ClaimValue": claim['ClaimValue'],
                    "ProviderAuthenticationScheme": claim['Provider']['AuthenticationScheme'],
                    "Description": claim['Description']
                }
            ]
        }
        response = client.post("Security/Roles", body=data, header_version=2)
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(msg=f"Could not create role for: {name}")
        logger.error(f"creating role: {e}")
        return False

def should_create(member_name, dry_run):
    """
    Determines whether an action to create a member should be executed or just logged.

    This function uses the provided parameters to decide if the process of creating
    a member should actually be performed (when ``dry_run`` is False) or merely
    logged as a simulated action (when ``dry_run`` is True). It returns a boolean
    value to indicate the result of the operation.

    :param member_name: The name of the member for whom the action is considered.
    :type member_name: str
    :param dry_run: A flag indicating whether the creation operation is a simulation
        (True) or should actually proceed (False). If True, the creation is logged
        but not performed.
    :type dry_run: bool
    :return: A boolean indicating whether the actual creation was performed.
    :rtype: bool
    """
    if dry_run:
        logger.info(f"DRYRUN: Creating for member: {member_name}")
        return False
    return True

def build_claim(claim) -> dict:
    """
    Builds and returns a formatted claim dictionary based on the provided claim input.

    This function processes a given claim, validates the claim type, maps it to an
    associated numeric value, and extracts additional claim details such as value,
    provider authentication scheme, and description. The resulting dictionary
    contains the processed claim information in a standardized format.

    :param claim: A dictionary containing claim information. It must have the
        attribute 'ClaimType', and may include 'ClaimValue', 'Provider', and
        'Description'.
    :type claim: dict

    :raises RuntimeError: If the provided 'ClaimType' is not recognized.

    :return: A dictionary mapping 'ClaimType' to a numeric identifier,
        along with other claim-related details such as 'ClaimValue',
        'ProviderAuthenticationScheme', and 'Description' if provided.
    :rtype: dict
    """
    if claim is None:
        raise ValueError("Claim cannot be None")
    if not isinstance(claim, dict):
        raise TypeError(f"Claim must be a dictionary, got {type(claim)}")
    CLAIM_TYPE_MAP = {
        "User": 0,
        "Group": 1,
        "Computer": 2,
        "OAuthOid": 3,
        "OAuthRole": 4,
        "OAuthSubject": 5,
        "OAuthClientId": 6,
    }
    ct = claim.get("ClaimType")

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
        raise RuntimeError(f"Unknown claim type: {ct}")

    provider = claim.get("Provider") or {}
    return {
        "ClaimType": claim_type_num,
        "ClaimValue": claim.get("ClaimValue"),
        "ProviderAuthenticationScheme": provider.get("AuthenticationScheme"),
        "Description": claim.get("Description"),
    }

def update_role(role, claim, name, dry_run):
    """
    Updates a role with a new claim and removes specified attributes before making an API request.

    This function processes a role by building a new claims payload based on existing claims
    and the provided claim. It updates the role's claims and removes certain attributes before
    sending the updated role object to the Keyfactor API.

    :param role: A dictionary representing the role object to be updated. It must include
                 a "Claims" key as a list.
    :param claim: A claim object to be appended to the role's claims list.
    :return: The response object in JSON format from the Keyfactor API if the request is
             successful. Returns "False" if an exception occurs during the API request.
    """
    if not should_create(name, dry_run):
        return
    new_claims_payload = []
    for rc in role["Claims"]:
        new_claims_payload.append(build_claim(rc))
    new_claims_payload.append(build_claim(claim))
    role["Claims"] = new_claims_payload
    del role["Immutable"]
    try:
        client = KeyfactorClient(variables)
        response = client.put(f"Security/Roles", body=role, header_version=2)
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(msg=f"updating role: {e}")
        return False

def get_role(name):
    try:
        client = KeyfactorClient(variables)
        base_path = f"Security/Roles?QueryString=Name%20-eq%20%22{name}%22"
        response = client.get(base_path, header_version=2)
        total_count_header = response.headers.get("x-total-count")
        if total_count_header is None:
            return False
        data = response.json()
        id = data[0].get('Id') if data else None
        base_path = f"Security/Roles/{id}"
        response = client.get(base_path, header_version=2)
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(msg=f"get roles: {e}")
        return False

load_variables(environment)
logger = get_logger()  # or logging.getLogger(__name__)
logger.info(msg=f"Starting Script for environment: {environment}")
logger.info(msg=f"Gathering all members of {variables['entra_all_users_group']} from gragh API's")
entra_members = get_graph_transitive_members(variables["entra_all_users_group"])
logger.info(msg=f"Gathering all roles from Keyfactor")
roles = get_roles()
logger.info(msg=f"Gathering all oauth claims from Keyfactor")
claims = get_claims()
for member in entra_members:
    member_name = member.get("displayName")
    newclaim = None
    if not any(claim['ClaimValue'] == member_name for claim in claims):
        logger.info(f"Member: {member_name} does not have a keyfactor claim. creating...")
        newclaim = create_claim(member_name, dry_run)
    elif any(claim['ClaimValue'] == member_name for claim in claims):
        logger.info(f"Member: {member_name} already has a keyfactor claim.  Checking roles...")
    if not any(role['Name'] == member_name for role in roles):
        logger.info(f"Member: {member_name} does not have a role. creating...")
        if not newclaim:
            claim = next((claim for claim in claims if claim['ClaimValue'] == member_name), None)
        else:
            claim = newclaim
        create_role(member_name, claim, dry_run)
    elif any(role['Name'] == member_name for role in roles):
        logger.info(f"Member: {member_name} already has a role. Checking if claim is in role...")
        role = get_role(member_name)
        if not any(claim['ClaimValue'] == member_name for claim in role['Claims']):
            logger.info(f"Member: {member_name} does not have a claim in role. adding claim to role...")
            if not newclaim:
                claim = next((claim for claim in claims if claim['ClaimValue'] == member_name), None)
            else:
                claim = newclaim
            if claim:
                update_role(role, claim, member_name,dry_run)
        else:
            logger.info(f"Member: {member_name} already has a claim in role.  No action needed.")
if dry_run:
    logger.info(msg="DRYRUN: Done. Exiting.")
else:
    logger.info(msg="Done. Exiting.")

import requests
import logging
import sys
import json
import urllib3
import time
# import automationassets       ##Uncomment to use Azure Automation Assets

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
environment = 'LAB'
log_level = logging.DEBUG


def load_variables():
    """
    Load a set of predefined variables required for client credentials, API access, and configuration.
    This function is designed to provide credentials, URLs, and other details typically required to
    interact with multiple APIs and systems such as Entra Graph APIs and Keyfactor API.

    The returned variables object contains key-value pairs for client-specific needs such as secret
    keys, token URLs, API scopes, audience values, and other configurations, which include
    SSL certificate settings and processing configurations like group and scheme names.

    :return: A dictionary containing predefined configuration variables.
    :rtype: dict
    """
    variables = {
        # Client credentials and URLs for both Entra Graph APIs
        'entra_client_id': '',
        'entra_client_secret': '',

        # Client Application for Keyfactor API Access
        'entra_token_url': '',
        'client_id': '',
        'client_secret': '',
        'token_url': '',
        'scope': '',
        'audience': '',

        # Keyfactor API base URL (Need to be set to the appropriate environment URL for production use)
        'keyfactordns': 'https://customer.keyfactorpki.com/KeyfactorAPI',

        # Provider Scheme as defined in Keyfactor for the claims
        'scheme': 'azure',

        # The name of the Entra group to pull nested groups from for processing
        'all_users_group': 'nested group name here',

        # Whether to verify SSL certificates when making API calls (set to False for testing with self-signed certs)
        'cert_check': True
    }
    return variables


class AppLogger:
    """
    Configures and provides a logger instance for the application.

    :param name: The name for the logger (typically the environment name).
    :type name: str
    :param log_level: The logging level (e.g., logging.DEBUG, logging.INFO).
    :type log_level: int
    """

    def __init__(self, name: str = environment, log_level: int = log_level):
        self.name = name
        self.log_level = log_level
        self._logger = self._setup_logger()

    def _setup_logger(self) -> logging.Logger:
        logger = logging.getLogger(self.name)
        logger.setLevel(self.log_level)

        # IMPORTANT: prevent double logging via root handlers
        logger.propagate = False

        if not logger.handlers:
            stream_handler = logging.StreamHandler(sys.stdout)  # <-- stdout, not default stderr
            stream_formatter = logging.Formatter(
                "%(asctime)s - %(levelname)s - %(name)s - %(message)s"
            )
            stream_handler.setFormatter(stream_formatter)
            logger.addHandler(stream_handler)

        return logger

    def get_logger(self) -> logging.Logger:
        """
        Returns the configured logger instance.

        :return: The logging.Logger instance.
        :rtype: logging.Logger
        """
        return self._logger


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

    # Helper to build full URL from base and endpoint
    def _build_url(self, endpoint: str) -> str:
        base = self.vars["keyfactordns"].rstrip("/")
        return f"{base}/{endpoint.lstrip('/')}"

    # helper to allow & in value for api call
    def _check_name(self, name: str):
        if '&' in name:
            name =  name.replace('&', '%26')
        return name

    def _create_auth_headers(self, header_version: int):
        """
        Creates authentication headers necessary for API requests by retrieving an access token
        using the specified client credentials and constructing a header with required fields.

        :param header_version: An integer representing the API version to be included in the headers.
        :return: A dictionary containing the authentication headers needed for API access.
        """
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
            timeout=30, verify=self.vars["cert_check"]
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

    def _request_with_retry(self, method: str, url: str, **kwargs):
        last_exception = None
        for attempt in range(1, self.retries + 1):
            try:
                logger.debug(f"Attempt {attempt}: {method.upper()} {url}")
                resp = self.session.request(method, url, timeout=60, verify=self.vars["cert_check"],
                                            **kwargs)
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

    def permissionset_name_get(self, name: str, header_version: int = 1):
        name = self._check_name(name)
        endpoint = f"PermissionSets?QueryString=Name%20-eq%20%22{name}%22"
        return (self.get(endpoint, header_version)).json()

    def claims_create_post(self, body: dict, header_version: int = 1):
        endpoint = f"Security/Claims"
        return (self.post(endpoint, body, header_version)).json()


class EntraClient:
    """
    Client for interacting with the Microsoft Graph API to retrieve Entra (Azure AD) group information.

    This class manages authentication against the Microsoft identity platform and provides
    methods for querying group membership via the Graph API.

    :ivar vars: Dictionary of configuration variables required for API communication.
                Must include 'entra_token_url', 'entra_client_id', 'entra_client_secret',
                and 'cert_check'.
    :type vars: dict
    :ivar session: A requests.Session object used for making HTTP requests.
    :type session: requests.Session
    """

    GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0"

    def __init__(self):
        self.vars = variables
        self.session = requests.Session()

    def _get_access_token(self) -> str:
        """
        Retrieves an access token from the Microsoft identity platform using client credentials.

        :return: The access token string.
        :rtype: str
        :raises requests.exceptions.RequestException: If the token request fails.
        """
        token_resp = self.session.post(
            self.vars["entra_token_url"],
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "client_credentials",
                "client_id": self.vars["entra_client_id"],
                "client_secret": self.vars["entra_client_secret"],
                "scope": "https://graph.microsoft.com/.default"
            },
            timeout=30, verify=self.vars["cert_check"]
        )
        token_resp.raise_for_status()
        return token_resp.json()["access_token"]

    def _get_auth_headers(self) -> dict:
        """
        Builds authorization headers using a freshly obtained access token.

        :return: A dictionary containing the Authorization and Content-Type headers.
        :rtype: dict
        """
        return {
            "Authorization": f"Bearer {self._get_access_token()}",
            "Content-Type": "application/json"
        }

    def get_group_id(self, group_name: str) -> str | None:
        """
        Retrieves the object ID for a group by its display name.

        :param group_name: The display name of the group to look up.
        :type group_name: str
        :return: The group's object ID, or None if not found.
        :rtype: str or None
        """
        headers = self._get_auth_headers()
        search_url = f"{self.GRAPH_BASE_URL}/groups?$filter=displayName eq '{group_name}'"
        search_resp = self.session.get(search_url, headers=headers, timeout=30, verify=self.vars["cert_check"])
        search_resp.raise_for_status()
        search_data = search_resp.json()
        if not search_data.get("value"):
            logger.warning(f"Group '{group_name}' not found")
            return None
        return search_data["value"][0]["id"]

    def get_transitive_members(self, group_name: str) -> list:
        """
        Retrieves the transitive group members for a given group name.

        :param group_name: The name of the group to fetch transitive members for.
        :type group_name: str
        :return: List of transitive group member display names in lowercase.
        :rtype: list
        """
        try:
            group_id = self.get_group_id(group_name)
            if group_id is None:
                return []

            headers = self._get_auth_headers()
            members_url = (
                f"{self.GRAPH_BASE_URL}/groups/{group_id}"
                f"/transitiveMembers/microsoft.graph.group?$select=displayName"
            )
            groups = []
            while members_url:
                members_resp = self.session.get(members_url, headers=headers, timeout=30,
                                                verify=self.vars["cert_check"])
                members_resp.raise_for_status()
                members_data = members_resp.json()
                group_members = [
                    item["displayName"]
                    for i, item in enumerate(members_data.get("value", []))
                    if isinstance(item, dict) and item.get("displayName") is not None
                       or logger.warning(f"value[{i}] missing 'displayName' key: {item}") is None
                ]
                logger.debug(
                    f"GET {members_resp.status_code} - {members_url} - Retrieved {len(group_members)} members"
                )
                groups.extend(group_members)
                members_url = members_data.get("@odata.nextLink")

            logger.info(f"Total transitive group members retrieved: {len(groups)}")
            return list(map(str.lower, groups))

        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching transitive group members from Entra for group '{group_name}': {e}")
            return []


class ClaimsProcessor:
    """
    Handles claim and role processing for Keyfactor provisioning.

    Provides methods to build, validate, and rebuild claims on roles,
    as well as create new roles via the Keyfactor API.

    :param keyfactor_client: An instance of KeyfactorClient used for API calls.
    :type keyfactor_client: KeyfactorClient
    :param config_vars: Dictionary of configuration variables (must include 'scheme').
    :type config_vars: dict
    :param app_logger: Logger instance for recording processing steps.
    :type app_logger: logging.Logger
    """

    CLAIM_TYPE_MAP = {
        "user": 0,
        "group": 1,
        "computer": 2,
        "oauthoid": 3,
        "oauthrole": 4,
        "oauthsubject": 5,
        "oauthclientId": 6,
    }
    OAUTH_CLAIM_NUMBERS = [3, 4, 5, 6]
    AD_CLAIM_NUMBERS = [0, 1, 2]

    def __init__(self, keyfactor_client: KeyfactorClient, config_vars: dict, app_logger: logging.Logger):
        self.client = keyfactor_client
        self.vars = config_vars
        self.logger = app_logger

    def build_oauth_claim(self, member_name: str) -> dict:
        """
        Builds an OAuth claim for the given member name.

        :param member_name: The name of the member for whom the OAuth claim is being created.
        :type member_name: str
        :return: A dictionary representing the new OAuth claim with attributes such as
            claimtype, claimvalue, providerauthenticationscheme, and description.
        :rtype: dict
        """
        self.logger.debug(f"building oauth claim for role")
        new_claim = {
            "claimtype": 4,
            "claimvalue": member_name,
            "providerauthenticationscheme": self.vars["scheme"],
            "description": member_name
        }
        self.logger.debug(f"new claim: {new_claim}")
        return new_claim

    def claims_check(self, role: dict, member_name: str) -> bool:
        """
        Checks if claims exist in the role data and verifies if a member name matches
        specific claim criteria.

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
        self.logger.info("Checking if claims are in role data")
        if role.get('Claims') is None or role.get('Claims') == []:
            self.logger.debug(f"Role has no claims: {role.get('Claims')}")
            return True

        for claim in role.get('Claims'):
            claim = to_lower(claim)
            member_name = member_name.lower()
            if claim.get('claimtype') == 'oauthrole' and member_name in claim.get('claimvalue', ''):
                return False
        return True

    def build_claim(self, claim: dict) -> dict:
        """
        Builds and validates a new claim object based on the given claim input.

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
        self.logger.info("Building Claim")
        try:
            if claim is None:
                raise ValueError("Claim cannot be None")
            if not isinstance(claim, dict):
                raise TypeError(f"Claim must be a dictionary, got {type(claim)}")
        except ValueError as ve:
            self.logger.error(f"Invalid claim: {ve}")
            self.logger.debug("Leaving build claim")

        claim = to_lower(claim)
        ct = claim.get("claimtype")

        if isinstance(ct, int):
            if ct not in self.CLAIM_TYPE_MAP.values():
                raise RuntimeError(f"Unknown claim type number: {ct}")
            claim_type_num = ct
        elif ct in self.CLAIM_TYPE_MAP:
            claim_type_num = self.CLAIM_TYPE_MAP[ct]
        else:
            self.logger.debug(f"ClaimType is a number: {ct}")
            self.logger.debug(f"ClaimType is a number: {claim}")
            raise RuntimeError(f"Unknown claim type: {ct}")

        provider = claim.get("provider") or {}
        if claim_type_num in self.OAUTH_CLAIM_NUMBERS:
            provider = {"authenticationscheme": self.vars["scheme"]}
        elif claim_type_num in self.AD_CLAIM_NUMBERS:
            provider = {"authenticationscheme": "Active Directory"}

        new_claim = {
            "claimType": claim_type_num,
            "claimValue": claim.get("claimvalue"),
            "providerAuthenticationScheme": provider.get("authenticationscheme"),
            "description": claim.get("description"),
        }
        self.logger.debug(f"new claim: {new_claim}")
        return new_claim

    def rebuild_claims(self, role: dict, new_claim: dict = None) -> dict:
        """
        Rebuilds and updates the claims of a role.

        :param role: A dictionary representing the role that contains a list of claims
                     under the 'Claims' key.
        :type role: dict
        :param new_claim: An optional new claim to be added to the role's claims.
                          Defaults to None.
        :type new_claim: dict, optional
        :return: The updated role with rebuilt claims.
        :rtype: dict
        """
        self.logger.info("Rebuilding Claims to update Role")
        existing_claims = []
        for claim in role['Claims']:
            claim = self.build_claim(claim)
            existing_claims.append(claim)
        if new_claim is not None:
            new_claim = self.build_claim(new_claim)
            existing_claims.append(new_claim)
        role['Claims'] = existing_claims
        self.logger.debug(f"Role Claims: {role.get('Claims')}")
        return role

    def build_new_role(self, member_name: str) -> dict:
        """
        Builds a new role for the provided member.

        :param member_name: The name to associate with the new role.
        :type member_name: str
        :return: The newly created role object returned from the API.
        :rtype: dict
        """
        self.logger.info("Creating New Role")
        data = {
            "name": member_name,
            "description": member_name,
            "emailaddress": "",
            "permissionSetid": (self.client.permissionset_name_get('global'))[0]['Id'],
            "permissions": [],
            "claims": [
                {
                    "claimtype": 4,
                    "claimvalue": member_name,
                    "providerauthenticationscheme": self.vars["scheme"],
                    "description": member_name
                }
            ]
        }
        new_role = self.client.role_create_post(data)
        self.logger.debug(f"Data Returned from API: {new_role}")
        return new_role


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


def main():
    """
    Entrypoint function for the script to process roles and claims for members in a specific Azure
    Active Directory group. This function sets up the necessary elements, initializes global variables,
    and handles member processing to ensure correct roles and claims are managed.

    :raises Exception: if an unexpected error occurs during the processing of a member.
    """
    global logger
    global variables
    global kfclient
    global claims_processor
    logger = AppLogger(name=environment, log_level=log_level).get_logger()
    variables = load_variables()
    kfclient = KeyfactorClient()
    claims_processor = ClaimsProcessor(kfclient, variables, logger)
    entra_client = EntraClient()
    logger.info(f"Starting Script for environment: {environment}")
    logger.info(f"Gathering all members of {variables['all_users_group']} from graph API's")
    entra_members = entra_client.get_transitive_members(variables["all_users_group"])
    for member_name in entra_members:
        try:
            logger.info(f"Starting to process member: {member_name}")
            logger.info(f"Getting role for: {member_name}")
            role = kfclient.role_get(member_name)
            role_needed = not role
            if role_needed:
                logger.info(f"Role not found for: {member_name}, creating new role.")
                claims_processor.build_new_role(member_name)
                continue
            else:
                logger.info(f"Role found for: {member_name}, checking claims in the role.")
                role = (kfclient.role_id_get(role[0]['Id']))
                logger.debug(f"Role Data: {role}")
                logger.info(f"Checking if claim is in Keyfactor")
                oauth_claim_needed = claims_processor.claims_check(role, member_name)
                logger.debug(f"claim needs added to role: {oauth_claim_needed}")
                if oauth_claim_needed:
                    new_claim = claims_processor.build_oauth_claim(member_name)
                    role = claims_processor.rebuild_claims(role, new_claim)
                    if 'Immutable' in role:
                        del role['Immutable']
                    logger.debug(msg=f"New Role Data: {role}")
                    kfclient.role_update_put(role)
                    continue
                else:
                    logger.info(f"Role is complete, Nothing to do for: {member_name}")
        except Exception as e:
            logger.error(f"An error occurred while processing member '{member_name}': {e}")
            continue

    logger.info("Script Finished. Exiting.")


if __name__ == "__main__":
    main()

try:
    import requests
    # Define script level variables for the script using a dictionary
    Variables = {
        # Authentication method (basic or oauth)
        "Auth_Method": "oauth",
        # Keyfactor's user credentials if Auth variable is set to Basic
        "keyfactorUser": "username",
        "keyfactorPassword": "password",

        # OAuth-specific parameters if Auth variable is set to oauth
        "client_id": "<ClientID>",
        "client_secret": "<ClientSecret>",
        "token_url": "<TokenURL>",
        "scope": "<SCOPE>",
        "audience": "<SCOPE>",
        "GlobalHeaders": {
            "Content-Type": "application/json",
            "x-keyfactor-requested-with": "APIClient"
        }
    }
except Exception:
    # If the variables could not be loaded, display a warning and stop the script
    raise Warning("Could not load variables")


def Get_Headers(APIVersion="1"):
    """
    Retrieve HTTP headers for API communication based on the configured
    authentication method.

    The function dynamically generates the required headers depending
    on whether the chosen authentication method is OAuth or Basic
    Authentication. If OAuth is utilized, it manages token retrieval
    with client credentials and constructs the appropriate header.
    With Basic Authentication, it encodes the credentials and formats
    them for use.

    :param APIVersion: The version of the API to be included in the
        "x-keyfactor-api-version" header. Defaults to "1".
    :type APIVersion: str
    :return: A dictionary containing the HTTP headers tailored to the
        specified API version and authentication method.
    :rtype: dict
    :raises Exception: Raised if the OAuth token retrieval process fails.
    """
    if Variables["Auth_Method"] == "oauth":
        authHeaders = {
            "Content-Type": "application/x-www-form-urlencoded"
        }
        authBody = {
            "grant_type": "client_credentials",
            "client_id": Variables["client_id"],
            "client_secret": Variables["client_secret"]
        }
        if Variables["scope"]:
            authBody["scope"] = Variables["scope"]
        if Variables["audience"]:
            authBody["audience"] = Variables["audience"]

        try:
            response = requests.post(
                Variables["token_url"],
                headers=authHeaders,
                data=authBody
            )
            response.raise_for_status()
            token = response.json()["access_token"]
            print("Access Token received successfully.")
            headers = Variables["GlobalHeaders"].copy()
            headers["Authorization"] = f"Bearer {token}"
            headers["x-keyfactor-api-version"] = APIVersion
        except Exception as e:
            print(f"Failed to fetch OAuth token: {str(e)}")
            raise
        return headers

    elif Variables["Auth_Method"] == "basic":
        import base64
        user_pass = f"{Variables['keyfactorUser']}:{Variables['keyfactorPassword']}"
        authInfo = base64.b64encode(user_pass.encode("ascii")).decode("ascii")
        headers = Variables["GlobalHeaders"].copy()
        headers["Authorization"] = f"Basic {authInfo}"
        headers["x-keyfactor-api-version"] = APIVersion
        return headers


print(Get_Headers(APIVersion="2"))

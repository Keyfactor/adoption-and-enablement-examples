import requests
import json
import click
from time import sleep

class AcmeClient:
    def __init__(self, variables: dict, retries: int = 1, backoff: int = 3):
        self.vars = variables
        self.session = requests.Session()
        self.retries = retries
        self.backoff = backoff

    # Helper to build full URL from base and endpoint
    def _build_url(self, endpoint: str, apitype: str = None) -> str:
        base = self.vars["acme_dns"].rstrip("/")
        if apitype == "keyfactor":
            base = self.vars["keyfactor_dns"].rstrip("/")
        return f"{base}/{endpoint.lstrip('/')}"

    def _create_auth_headers(self, api_type: str = None):
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
        token = token_resp.json()["access_token"]
        if api_type == None:
            return {"Authorization": f"Bearer {token}", 'Content-Type': "application/json"}
        elif api_type == 'keyfactor':
            return {"Authorization": f"Bearer {token}", "x-keyfactor-requested-with": "APIClient",
                    "x-keyfactor-api-version": "1.0"}
        else:
            raise ValueError("Unsupported API type")

    def _request_with_retry(self, method: str, url: str, **kwargs):
        last_exception = None
        for attempt in range(1, self.retries + 1):
            try:
                resp = self.session.request(method, url, timeout=60, verify=self.vars["cert_check"],
                                            **kwargs)
                resp.raise_for_status()
                return resp
            except requests.RequestException as e:
                click.secho(f"Attempt {attempt} failed: {e}")
                last_exception = e
                if attempt < self.retries:
                    sleep(self.backoff)
        raise last_exception

    def get(self, endpoint: str, apitype: str):
        headers = self._create_auth_headers(apitype)
        url = self._build_url(endpoint, apitype)
        return self._request_with_retry("get", url, headers=headers)

    def post(self, endpoint: str, body: dict = {}, apitype: str = None):
        headers = self._create_auth_headers(apitype)
        url = self._build_url(endpoint, apitype)
        return self._request_with_retry("post", url, headers=headers, data=json.dumps(body))

    def put(self, endpoint: str, body: dict, apitype: str):
        headers = self._create_auth_headers(apitype)
        url = self._build_url(endpoint, apitype)
        return self._request_with_retry("put", url, headers=headers, data=json.dumps(body))

    def delete(self, endpoint: str, apitype: str):
        headers = self._create_auth_headers(apitype)
        url = self._build_url(endpoint, apitype)
        return self._request_with_retry("delete", url, headers=headers)

    def status_get(self, apitype: str = None):
        response = self.get("status", apitype)
        return response.status_code == 204

    def claim_put(self, id: str, body, apitype: str = None):
        return self.put(f"Claims/{id}", body, apitype)

    def claim_post(self, body: dict, apitype: str = None):
        return self.post(f"Claims", body, apitype)

    def claim_get(self, id:str = None, apitype: str = None):
        return self.get(f"Claims/{id}" if id else "Claims", apitype)

    def claim_delete(self, id:str = None, apitype: str = None):
        return self.delete(f"Claims/{id}", apitype)

    def key_management_get(self, template:str, headers, apitype: str = None):
        url = self._build_url(f"KeyManagement?Template={template}", apitype)
        return self._request_with_retry("get", url, headers=headers)

    def key_management_post(self, body: dict, apitype: str = None):
        return self.post("KeyManagement",body, apitype)

    def identifier_add_post(self, body, apitype: str = None):
        return self.post(f"Identifiers", body, apitype)

    def identifier_get(self, apitype: str = None):
        return self.get(f"Identifiers", apitype)

    def identifier_delete(self, id:str = None, apitype: str = None):
        return self.delete(f"Identifiers/{id}", apitype)

    def admin_accounts_put(self, id:str ,body = dict, apitype: str = None):
        return self.put(f"Admin/Accounts/{id}", body, apitype)

    def admin_accounts_get(self, apitype: str = None):
        return self.get(f"Admin/Accounts/List", apitype)

    def admin_accounts_revoke_post(self, acount_id:str, deleteKey:bool = False, apitype: str = None):
        url = f"Admin/Accounts/Revoke?accountId={acount_id}&deleteKey=true" if deleteKey else f"Admin/Accounts/Revoke?accountId={acount_id}"
        return self.post(url, apitype)

    def app_settings_get(self, apitype: str = None):
        return self.get(f"AppSettings", apitype)

    def app_settings_put(self, id:int, value:dict, apitype: str = None):
        return self.put(f"AppSettings/{id}",value, apitype)

    def template_patterns_get(self, apitype: str = "keyfactor"):
        return self.get(f"EnrollmentPatterns?QueryString=AllowedEnrollmentType%20-eq%20%222%22&ReturnLimit=100", apitype)
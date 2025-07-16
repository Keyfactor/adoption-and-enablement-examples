# API Headers Generator

This repository contains a Python script for generating HTTP headers for API communication based on the chosen authentication method (`OAuth` or `Basic Authentication`). It dynamically constructs the required headers to interact with APIs securely and efficiently.

## Features

- Supports both **OAuth** and **Basic Authentication** for API communication.
- Dynamically retrieves access tokens for OAuth.
- Encodes credentials for Basic Authentication.
- Configurable through a single dictionary, ensuring flexibility and adaptability.

---

## Installation

1. **Clone the Repository**
    ```bash
    git clone https://github.com/yourusername/api-headers-generator.git
    cd api-headers-generator
    ```

2. **Install Required Dependencies**
    Make sure you have [Python 3.10 or higher](https://www.python.org/downloads/) installed.

    Install dependencies with:
    ```bash
    pip install requests
    ```

---

## Usage

1. **Set Authentication Configuration**

    Update the `Variables` dictionary inside the script with the appropriate values according to your API authentication method. 

    ### For OAuth
    Set the following values in the `Variables` dictionary:
    - `Auth_Method`: `"oauth"`
    - `client_id`: Your application client ID.
    - `client_secret`: Your application client secret.
    - `token_url`: The token generation URL from your API provider.
    - `scope` & `audience`: (Optional) Specific values required by your API if applicable.

    Example Configuration:
    ```python
    Variables = {
        "Auth_Method": "oauth",
        "client_id": "YourClientID",
        "client_secret": "YourClientSecret",
        "token_url": "https://api.example.com/oauth/token",
        "scope": "api.read.api.write",
        "audience": "https://api.example.com/",
        "GlobalHeaders": {
            "Content-Type": "application/json",
            "x-keyfactor-requested-with": "APIClient"
        }
    }
    ```

    ### For Basic Authentication
    Set the following values:
    - `Auth_Method`: `"basic"`
    - `keyfactorUser`: The username for your API.
    - `keyfactorPassword`: The password for your API.

    Example:
    ```python
    Variables = {
        "Auth_Method": "basic",
        "keyfactorUser": "yourUsername",
        "keyfactorPassword": "yourPassword",
        "GlobalHeaders": {
            "Content-Type": "application/json",
            "x-keyfactor-requested-with": "APIClient"
        }
    }
    ```

2. **Call the `Get_Headers` Function**
    The function `Get_Headers` generates headers for API communication:

    Example:
    ```python
    from get_headers import Get_Headers

    headers = Get_Headers(APIVersion="2")
    print(headers)
    ```

3. **Run the Script**
    Execute the script to test functionality:
    ```bash
    python get_headers.py
    ```

---

## How It Works

The script dynamically generates HTTP headers using the following logic based on the configured authentication method:

1. **OAuth Authentication**:
   - Sends a `POST` request to the token endpoint using client credentials (`client_id`, `client_secret`).
   - Retrieves the `access_token` from the response.
   - Sets the `Authorization` header as `Bearer <access_token>`.

2. **Basic Authentication**:
   - Encodes the username and password using Base64.
   - Sets the `Authorization` header as `Basic <encoded_credentials>`.

---

## Example Output

Example using OAuth authentication:
```json
{
    "Content-Type": "application/json",
    "x-keyfactor-requested-with": "APIClient",
    "Authorization": "Bearer some_access_token",
    "x-keyfactor-api-version": "2"
}
```

---

## Error Handling

If the script fails to:
- **Fetch OAuth Token**: Prints the error and raises an exception.
- **Load Configuration Variables**: Raises a `Warning`.

---

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

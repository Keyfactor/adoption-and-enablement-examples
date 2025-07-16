# API Authentication Header Generator

This PowerShell script dynamically generates HTTP request headers for APIs that require **Basic Authentication** or **OAuth Authentication**. It provides flexibility by supporting multiple authentication methods with customizable parameters.

---

## Features

### Authentication Support
- **Basic Authentication**: Encodes a username and password into a Base64 string for secure authorization.
- **OAuth Authentication**: Makes a POST request to an OAuth server to retrieve a `Bearer` token for authorization.

### Dynamic API Versioning
- The `Get-Headers` function accepts an optional `APIVersion` parameter to include the desired API version in the request headers.

### Configurable Global Headers
- Shared headers such as `Content-Type` or custom values can be easily defined and reused for all requests.

### Error Handling
- Built-in `try-catch` blocks provide robust error handling for API token requests and header generation failures.

---

## Script Workflow

1. Define global script variables, including:
   - Authentication Method (`basic` or `oauth`)
   - Credentials (username/password or OAuth parameters)
   - Base headers for all requests
2. Call the `Get-Headers` function to generate authentication headers.
3. Use the generated headers in your API calls.

---

## How It Works

### Variables

The script uses a dictionary `Variables` to store key pieces of information, such as credentials, OAuth details, and shared headers.

```powershell
$Script:Variables = @{
    Auth_Method = "basic"   # Authentication method: "basic" or "oauth"
    keyfactorUser = "username"   # Basic Authentication username
    keyfactorPassword = "password"   # Basic Authentication password
    
    # OAuth-specific variables
    client_id = "<ClientId>"         # OAuth client ID
    client_secret = "<ClientSecret>" # OAuth client secret
    token_url = "<TokenURL>"         # URL to fetch OAuth token
    scope = "<Scope>"                # Optional OAuth scope
    audience = "<Audience>"          # Optional OAuth audience

    # Common headers
    GlobalHeaders = @{
        "Content-Type" = "application/json"
        "x-keyfactor-requested-with" = "APIClient"
    }
}
```

### `Get-Headers` Function

This is the main function of the script. It returns the necessary HTTP headers based on the defined authentication method.

**Parameters:**
- `APIVersion`: Specifies the API version to include in the headers (optional, defaults to `1`).

**Logic:**
1. Checks the `Auth_Method` value:
   - If `"basic"`, adds Base64-encoded credentials to the headers.
   - If `"oauth"`, retrieves a `Bearer` token from the specified OAuth server and adds it to the headers.
2. Returns customized headers, which include:
   - `Authorization`: Either `"Basic <Base64String>"` or `"Bearer <OAuthToken>"`
   - API Version Header: `"x-keyfactor-api-version: <APIVersion>"`

---

## Example Usage

### Basic Authentication
Set `Auth_Method` to `"basic"` and provide a username/password.

```powershell
# Define variables
$Script:Variables.Auth_Method = "basic"
$Script:Variables.keyfactorUser = "exampleUser"
$Script:Variables.keyfactorPassword = "examplePassword"

# Generate headers
$headers = Get-Headers -APIVersion "2"

# Use headers in an API request
Invoke-RestMethod -Uri "https://api.example.com/resource" -Headers $headers
```

### OAuth Authentication
Set `Auth_Method` to `"oauth"` and populate `client_id`, `client_secret`, and other optional parameters.

```powershell
# Define variables
$Script:Variables.Auth_Method = "oauth"
$Script:Variables.client_id = "<YourClientID>"
$Script:Variables.client_secret = "<YourClientSecret>"
$Script:Variables.token_url = "https://auth.example.com/oauth/token"
$Script:Variables.scope = "read write"

# Generate headers
$headers = Get-Headers -APIVersion "1"

# Use headers in an API request
Invoke-RestMethod -Uri "https://api.example.com/resource" -Headers $headers
```

---

## Error Handling

The script includes comprehensive error handling to manage potential issues, including:
- Failure to fetch an OAuth token.
- Issues encoding credentials or cloning headers.

**Examples:**
- If OAuth token retrieval fails:
  ```text
  Failed to fetch OAuth token: <Error Message from API>
  ```
- If the authentication method is unsupported:
  ```text
  Unsupported Auth_Method: <Invalid Authentication Method>
  ```

---

## Prerequisites

- PowerShell (Version 5.1 or later)
- Access to the API and credentials for the chosen authentication method

---

## Files

- **Script Contents:** The main script includes the full implementation of the `Get-Headers` function.
- **Example Testing Block:** A section at the end of the script demonstrates how the function can be tested.

---

## Customization

- Update `GlobalHeaders` as needed to include additional headers required by your API.
- Modify OAuth-specific variables such as `scope` or `audience` based on your use case.
- Add more authentication methods or enhance logging by extending the `Get-Headers` function.

---

## Troubleshooting

### Common Issues
- **Invalid Credentials:** Ensure the username/password or OAuth client ID/secret are correct.
- **Token URL Errors:** Verify that the `token_url` parameter is correct for your OAuth server.
- **API Version Mismatch:** Pass the correct `APIVersion` parameter for your API.

### Debugging
- To view detailed logs, set `$InformationPreference` to `"Continue"`.
- Use `Write-Information` statements in the script for additional tracing.

---

## License

This script is licensed under the MIT License. You are free to use, modify, and distribute it for personal or commercial purposes.
# Certificate Ownership Updater

This project provides a multithreaded Python script to update the owners of certificates in a Keyfactor API-based solution. It reads input data from a CSV file, connects to the API, retrieves certificate and role data, and updates ownership information accordingly. Logs are created for all operations.

---

## Features

- **Multithreading**: Efficient processing of large data using a configurable number of threads.
- **Dynamic Role Assignment**: Updates certificate roles based on the provided CSV input.
- **Logging**: Detailed logging for each operation, including API interactions and potential errors.
- **API Integration**: Supports secure interaction with APIs using authentication headers.

---

## Prerequisites

- **Python 3.8 or later**
- Required Python libraries:
  - `requests`
  - `csv`
  - `json`
  - `concurrent.futures` (built-in module)
  - `datetime`
  - `functools`
  - `urllib.parse`
  
To install any missing packages, run:

```bash
pip install requests
```

---

## File Overview

### Script Files:
- **`owner_update.py`**: The main script for updating certificate ownership.
  
### Input Files:
- **`CSV File`**: Contains data to be processed (e.g., serial numbers and roles).
  - Example:
    ```csv
    serial,role
    ABC12345,AdminRole
    XYZ67890,UserRole
    ```
- **`Variable File`**: A Python file defining additional configuration:
  - Example (`variables.py`):
    ```python
    TOKEN_URL = "https://your-keyfactor-domain/api/auth/token"
    KEYFACTORAPI = "https://your-keyfactor-domain/api"
    client_id = "YOUR_CLIENT_ID"
    client_secret = "YOUR_CLIENT_SECRET"
    ```

---

## How to Use

1. **Clone the Repository**:
    ```bash
    git clone https://your-repository-link.git
    cd your-repository
    ```

2. **Prepare Configuration Files**:
   - Create a CSV file (e.g., `input.csv`) with certificate serial numbers and the target roles.
   - Create a Python script (e.g., `variables.py`) with API configurations.

3. **Run the Script**:
   - Syntax:
     ```bash
     python owner_update.py <path_to_csv> <max_threads> <path_to_variable_file>
     ```
   - Example:
     ```bash
     python owner_update.py input.csv 5 variables.py
     ```

---

## Functions

The script consists of the following key functions:

1. **Logging**:
   - `create_log_directory`: Ensures the required log directory exists.
   - `new_log_entry`: Writes logs for each operation.

2. **API Interaction**:
   - `create_auth`: Generates authentication headers for API requests.
   - `invoke_http_get`: Sends GET requests with appropriate headers.
   - `invoke_http_put`: Sends PUT requests with authentication.

3. **Certificate and Role Management**:
   - `get_certificates`: Fetches certificate details based on serial numbers.
   - `get_role_id`: Retrieves role IDs for given roles.
   - `update_certificate_owner`: Updates the owner of a specified certificate.

4. **Orchestration**:
   - `process_line`: Processes a single line from the input CSV file.
   - `main`: Configures multithreading, reads input, and initiates processing.

---

## Logs

Logs are stored in a folder named `RunspaceLogs` (created in the current working directory). Each log file's naming format is `log_<serial>.log`.

---

## Error Handling

- If the Keyfactor API is unreachable, a validation error is logged.
- Errors in API requests (e.g., invalid credentials or IDs) are recorded in the logs.

---

## Example Run

1. **Input CSV (`input.csv`)**:
   ```csv
   serial,role
   ABC12345,AdminRole
   XYZ67890,UserRole
   ```

2. **Variable Configuration (`variables.py`)**:
   ```python
   TOKEN_URL = "https://example.com/api/auth/token"
   KEYFACTORAPI = "https://example.com/api"
   client_id = "example_client_id"
   client_secret = "example_client_secret"
   ```

3. **Command**:
   ```bash
   python owner_update.py input.csv 5 variables.py
   ```

4. **Output**:
   ```
   Elapsed time: 10.50 seconds
   All tasks completed using multithreading. Logs created in RunspaceLogs.
   ```

---

## Notes and Limitations

- Ensure Keyfactor API and credentials are correctly configured.
- CSV file headers must include `serial` and `role`.
- Multi-threaded processing is configurable via the `max_threads` parameter.
- Logs include timestamps, API call details, and error messages.

---

## Links
- [Explination of Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/Owner_Update/Code.md)
- [Example CSV](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/Owner_Update/Sample.CSV)
- [Variable File](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/Owner_Update/Variables.ps1)
- [Keyfactor Command Documentation](https://software.keyfactor.com)
## License
This script is licensed under the MIT License.

---

### Author
© 2025 Keyfactor
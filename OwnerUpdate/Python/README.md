# Certificate Management System

This Python-based application is designed to handle certificate management tasks, file processing, and logging. It integrates with external APIs for authentication and certificate actions, supporting multithreaded file processing.

---

## Features

- **Dynamic Function Import**: Import Python functions dynamically from files.
- **Logging**: Handles organized logging with timestamps.
- **OAuth 2.0 Authentication**: Fetches bearer tokens using the client credentials grant type.
- **Certificate Management**: Integrates with a certificate management API to:
  - Check system status.
  - Fetch certificate and role details.
  - Update certificate ownership.
- **File Processing**: Processes CSV files:
  - Validates file structure.
  - Processes data in multithreaded mode.

---

## Requirements

- Python 3.8 or higher
- Installed Python libraries:
  - `requests`
  - `argparse`
  - `json`
  - `urllib.parse`
  - `csv`
  - `threading`
  - `importlib`

---

## Installation

1. **Clone the Repository**:
   ```bash
   git clone <repository_url>
   cd <repository_directory>
   ```

2. **Install Dependencies**:
   Ensure you have the required Python packages installed:
   ```bash
   pip install requests
   ```

---

## Configuration

The application relies on a configuration file to manage environment-specific settings. The configuration must provide:
- **Base URL** of the certificate management API.
- **OAuth 2.0 Credentials** (client ID, secret, token URL, and scope).
- **Log Directory** and **CSV File Path**.

An example configuration structure:
```json
{
  "token_url": "<OAuth_Token_Endpoint>",
  "client_id": "<Client_ID>",
  "client_secret": "<Client_Secret>",
  "scope": "<Access_Scope>",
  "audience": "<Audience>",
  "log_dir": "./logs",
  "csv_path": "./data.csv",
  "base_url": "<Certificate_Management_Base_URL>"
}
```

Ensure this configuration file is passed when running the application with the `--config` flag.

---

## Usage

Run the application using the following command:
```bash
python <script_name>.py --config <config_file_path> --env <environment>
```

- **Arguments**:
  - `--config` (`-c`): Path to the configuration file.
  - `--env` (`-e`): Target environment (`prod` or `dev`).

---

## Project Structure

### Main Components

1. **LogManager**:
   - Handles log directory creation and log entry writing.
   - Ensures smooth logging functionality.

2. **Authenticator**:
   - Handles OAuth 2.0 authentication workflows.
   - Obtains bearer tokens using client credentials.

3. **CertificateManager**:
   - Facilitates interactions with a certificate management system.
   - Performs certificate and role-related operations.

4. **FileProcessor**:
   - Processes CSV files for certificate updates.
   - Utilizes multithreading for efficient processing.

5. **MainApplication**:
   - Integrates all components for end-to-end execution.
   - Handles file validation, logging, and processing workflows.

### Key Functions

- `dynamic_import`: Dynamically imports and executes functions from other Python modules.

---

## Workflow

1. **Authentication**: Obtain a bearer token from the OAuth 2.0 service.
2. **Logging**: Create log directories and log application events.
3. **File Validation**: Validate the structure of the specified CSV file.
4. **Multithreaded Processing**: Process each CSV line to update certificates in parallel.
5. **API Integration**: Interact with the certificate management API to:
   - Retrieve certificate and role details.
   - Update ownership information.

---

## Example CSV Structure

The input CSV file must contain the following headers:
- `serial`: Certificate serial number.
- `role`: Role to assign as the owner.

Example:
```csv
serial,role
12345,Admin
67890,Operator
```

---

## Error Handling

- **Logging**: All errors and processing events are logged in the specified log directory.
- **API Communication**: Handles exceptions related to API requests and logs failures with details.

---

## Links
- [Explination of Code](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/OwnerUpdate/Python/Code.md)
- [Example CSV](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/OwnerUpdate/Python/Sample.CSV)
- [Variable File](https://github.com/Keyfactor/adoption-and-enablement-examples/blob/OwnerUpdate/OwnerUpdate/Python/Variables.ps1)
- [Keyfactor Command Documentation](https://software.keyfactor.com)


## License

This project is licensed under the MIT License.

### Author
© 2025 Keyfactor
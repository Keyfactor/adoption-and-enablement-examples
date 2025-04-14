import os
import requests
import argparse
import csv
import json
import urllib.parse
import threading
import importlib.util


def dynamic_import(module_path: str, function_name: str):
    """
    Dynamically import a function from a specified file.

    :param module_path: The path to the Python file containing the function to import.
    :param function_name: The name of the function to import from the file.
    :return: The imported function.
    """
    spec = importlib.util.spec_from_file_location("dynamic_module", module_path)
    dynamic_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dynamic_module)
    return getattr(dynamic_module, function_name)


class LogManager:
    """
    Handles logging functionality, including the creation of a log directory and
    adding new log entries with timestamps. This class is designed to ensure smooth
    and organized logging operations for applications.

    :ivar log_dir: The directory path where log files will be stored.
    :type log_dir: str
    """
    def __init__(self, cm_config: dict):
        self.log_dir = cm_config['log_dir']

    def create_log_directory(self):
        """Creates a log directory if it doesn't exist."""
        if not os.path.exists(self.log_dir):
            os.makedirs(self.log_dir)

    def new_log_entry(self, entry: str):
        """Adds a new log entry with a timestamp."""
        from datetime import datetime
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"[{timestamp}] {entry}\n"
        log_file_path = os.path.join(self.log_dir, "application.log")
        with open(log_file_path, "a") as log_file:
            log_file.write(log_entry)

class Authenticator:
    """
    Authenticator is responsible for obtaining OAuth2.0 bearer tokens using client credentials.

    This class is designed to help in authentication workflows that require fetching an access
    token from an authorization server's token endpoint using the client credentials grant type.
    It provides flexibility to include additional options such as scope and audience in the token
    request.

    :ivar token_url: The URL of the token endpoint provided by the authorization server.
    :type token_url: str
    :ivar client_id: The client identifier issued by the authorization server.
    :type client_id: str
    :ivar client_secret: The client secret issued by the authorization server.
    :type client_secret: str
    :ivar scope: Optional scope parameter for limiting the access token's permissions.
    :type scope: str | None
    :ivar audience: Optional audience parameter to specify the intended recipient of the token.
    :type audience: str | None
    """
    def __init__(
            self,
            token_url: str,
            client_id: str,
            client_secret: str,
            scope: str = None,
            audience: str = None):

        self.client_id = client_id
        self.client_secret = client_secret
        self.token_url = token_url
        self.scope = scope
        self.audience = audience

    def get_bearer_token(self, scope: str) -> str:
        data = {
            "grant_type": "client_credentials",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
        }
        if scope:
            data["scope"] = scope
        if self.audience:
            data["audience"] = self.audience
        try:
            response = requests.post(self.token_url, data=data)
            response.raise_for_status()  # Raise an HTTPError for bad responses (4xx and 5xx)
        except requests.exceptions.RequestException as e:
            raise Exception(f"Failed to fetch bearer token: {e}")
        token_data = response.json()
        if "access_token" not in token_data:
            raise Exception(f"Failed to retrieve access token: {token_data.get('error_description', 'Unknown error')}")
        return token_data["access_token"]

class CertificateManager:
    """
    Manages interactions with a certificate management system through API calls.

    The class provides methods to perform actions such as fetching certificate information, checking the health
    of the Keyfactor system, retrieving role data, and updating certificate ownership. It utilizes a logging
    mechanism to record events and errors during its operations.

    :ivar log_manager: A LogManager instance for creating new log entries.
    :type log_manager: LogManager
    :ivar base_url: The base URL of the certificate management API.
    :type base_url: str
    :ivar token: Access token used for authenticating API requests.
    :type token: str
    :ivar serial: Serial number of the certificate (optional).
    :type serial: str, optional
    :ivar role: Name of the role associated with the instance (default is None).
    :type role: str, optional
    """
    def __init__(self, log_manager: LogManager, cm_config: dict, serial: str=None):
        self.log_manager = log_manager
        self.base_url = cm_config['base_url']
        self.token = cm_config['token']
        self.serial = serial
        self.role = None

    def get_certificates(self, serial: str):
        try:
            encoded_query = urllib.parse.quote(f'SerialNumber -eq "{serial}"')
            response = requests.get(f"{self.base_url}/Certificates?QueryString={encoded_query}",
                                    headers=KeyfactorHeaders(header_version='1', access_token=self.token).to_dict())
            return json.loads(response.text)[0]["Id"]
        except Exception as e:
            self.log_manager.new_log_entry(f"Error fetching certificates: {str(e)}")
            return False

    def check_keyfactor_status(self):
        try:
            response = requests.get(f"{self.base_url}/status/healthcheck",
                                    headers=KeyfactorHeaders(header_version='1', access_token=self.token).to_dict())
            return response.status_code == 204
        except Exception as e:
            self.log_manager.new_log_entry(f"Error checking Keyfactor status: {str(e)}")
            return False

    def get_roles(self, role: str):
        try:
            encoded_query = urllib.parse.quote(f'name -eq "{role}"')
            response = requests.get(f"{self.base_url}/Security/Roles?QueryString={encoded_query}",
                                    headers=KeyfactorHeaders(header_version='2', access_token=self.token).to_dict())
            return json.loads(response.text)[0]["Id"]
        except Exception as e:
            self.log_manager.new_log_entry(f"Error fetching roles: {str(e)}")
            return False

    def update_certificate_owner(self, certificate_id: str, owner_id: int):
        try:
            self.log_manager.new_log_entry(f"Updating certificate with id {certificate_id} with owner id {owner_id}")
            response = requests.put(
                f"{self.base_url}/Certificates/{certificate_id}/Owner",
                headers=KeyfactorHeaders(header_version='1', access_token=self.token).to_dict(),
                json={"NewRoleId": owner_id}
            )
            return response.status_code == 204
        except Exception as e:
            self.log_manager.new_log_entry(f"Error updating certificate: {str(e)}")
            return False

class FileProcessor:
    """
    Handles file processing operations, including validation, file processing using multithreading,
    and line-by-line processing for specific operations. This class is designed to work with a
    configuration that includes CSV file paths and LogManager for logging operations.

    :ivar csv_path: Path to the CSV file that needs to be processed.
    :type csv_path: str
    :ivar log_manager: Instance of LogManager to handle logging operations.
    :type log_manager: LogManager
    """
    def __init__(self, cm_config: dict):
        self.csv_path = cm_config['csv_path']
        self.log_manager = LogManager(cm_config=cm_config)

    def validate_csv_file(self):
        required_headers = {'serial', 'role'}
        try:
            with open(self.csv_path, mode='r', encoding='utf-8-sig') as csv_file:
                reader = csv.DictReader(csv_file)
                if not required_headers.issubset(reader.fieldnames):
                    return False
            return True
        except Exception as e:
            self.log_manager.new_log_entry(f"Error validating CSV file: {str(e)}")
            return False

    def process_file_multithreaded(self):
        threads = []
        with open(self.csv_path, 'r') as file:
            for line in file:
                thread = threading.Thread(target=self.process_line, args=(line,))
                threads.append(thread)
                thread.start()

                # Optional: Limit the number of active threads
                if len(threads) >= 10:  # Example: Max 10 threads
                    for t in threads:
                        t.join()
                    threads = []
        for t in threads:
            t.join()

    def process_line(self, line: str, certificate_manager: CertificateManager):
        certificate_id = certificate_manager.get_certificates(serial=line.split(',')[0].strip())
        role_id = certificate_manager.get_roles(role=line.split(',')[1].strip())
        if certificate_id and role_id:
            if certificate_manager.update_certificate_owner(certificate_id=certificate_id, owner_id=role_id):
                self.log_manager.new_log_entry(f"Certificate with serial {line.split(',')[0]} updated with role {line.split(',')[1]}")
            else:
                self.log_manager.new_log_entry(f"[ERROR]Error updating certificate with serial {line.split(',')[0]} and role {line.split(',')[1]}")
        else:
            self.log_manager.new_log_entry(f"[ERROR]Error updating certificate with serial {line.split(',')[0]} and role {line.split(',')[1]}")

class KeyfactorHeaders:
    """
    Represents headers required for connecting to the Keyfactor API.

    This class encapsulates the standard headers used for API requests to
    the Keyfactor system. It is designed to streamline the construction of
    HTTP headers by predefining static values and dynamically generating
    others based on input parameters.

    :ivar content_type: Specifies the content type for the request payloads.
    :type content_type: str
    :ivar accept: Denotes the type of response format expected from the API.
    :type accept: str
    :ivar x_keyfactor_requested_with: Indicates the client making the
        request (fixed to "APIClient").
    :type x_keyfactor_requested_with: str
    :ivar x_keyfactor_api_version: Represents the Keyfactor API version to
        be used in the request.
    :type x_keyfactor_api_version: str
    :ivar authorization: Contains the Bearer token for authorizing API
        requests.
    :type authorization: str
    """
    def __init__(self, header_version: str, access_token: str):
        self.content_type = "application/json"
        self.accept = "text/plain"
        self.x_keyfactor_requested_with = "APIClient"
        self.x_keyfactor_api_version = f"{header_version}.0"
        self.authorization = f"Bearer {access_token}"

    def to_dict(self) -> dict:
        return {
            "content-type": self.content_type,
            "accept": self.accept,
            "x-keyfactor-requested-with": self.x_keyfactor_requested_with,
            "x-keyfactor-api-version": self.x_keyfactor_api_version,
            "Authorization": self.authorization
        }

class MainApplication:
    """
    Represents the main application for managing and processing files, handling logs, and
    certificates validation. It facilitates file validation, logs creation, and data processing
    workflows.

    :ivar log_manager: Instance of LogManager to handle logging operations.
    :type log_manager: LogManager
    :ivar certificate_manager: Handles certificate-related operations using log_manager and
        configuration.
    :type certificate_manager: CertificateManager
    :ivar file_processor: Manages file processing, including validation and line processing
        functionalities.
    :type file_processor: FileProcessor
    """
    def __init__(self, cm_config: dict):
        self.log_manager = LogManager(cm_config=cm_config)
        self.certificate_manager = CertificateManager(self.log_manager, cm_config=cm_config)
        self.file_processor = FileProcessor(cm_config=cm_config)

    def run(self):
        print("Creating Log Directory...")
        self.log_manager.create_log_directory()
        print("Validating CSV File...")
        if not self.file_processor.validate_csv_file():
            self.log_manager.new_log_entry("Invalid file format.")
            return
        else:
            self.log_manager.new_log_entry("CSV File validation successful.")
        with open(self.file_processor.csv_path, 'r') as file:
            csv_reader = csv.reader(file)
            next(csv_reader)
            print("Processing CSV File...")
            for line in file:
                self.file_processor.process_line(line, self.certificate_manager)

def main():
    """
    Main entry point for the script/application. This function parses command-line
    arguments, validates configurations, initializes necessary components, and
    launches the main application logic.

    :raises SystemExit: Exits the program in case of invalid or unavailable resources.

    :param: None

    :return: None
    """
    parser = argparse.ArgumentParser(
        description="A description of what your script/application does."
    )

    parser.add_argument(
        '-c','--config',
        type=str,
        help='Path to the configuration file',
        required=True
    )
    parser.add_argument(
        '-e','--env',
        type=str,
        help='prod or dev',
        required=True
    )

    args = parser.parse_args()

    print(f"Config file: {args.config}")
    if args.env:
        print(f"Environment: {args.env}")

    get_config = dynamic_import(args.config, 'get_config')

    config = get_config(env=args.env)

    authenticator = Authenticator(token_url=config['token_url'], client_id=config['client_id'], client_secret=config['client_secret'], scope=config['scope'], audience=config['audience'])
    config['token'] = authenticator.get_bearer_token(scope=config['scope'])

    certificate_manager = CertificateManager(cm_config=config,log_manager=LogManager(cm_config=config))
    if not (certificate_manager.check_keyfactor_status()):
        print("Keyfactor is not available")
        exit()
    else:
        print("Validated Connection to Keyfactor")
    app = MainApplication(config)
    app.run()
    print("Completed Successfully")

if __name__ == "__main__":
    main()


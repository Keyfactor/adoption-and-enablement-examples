
import os
import json
import csv
import requests
from functools import partial
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import time
import urllib.parse



# Function to create the log directory
def create_log_directory(log_path):
    """
    Creates a log directory if it does not already exist.

    This function checks whether the specified log directory path exists.
    If it does not exist, the directory is created. The function ensures
    that appropriate directories are in place for logging purposes in
    applications.

    :param log_path: The full path of the directory to create if it does
        not exist.
    :type log_path: str
    :return: None
    """
    if not os.path.exists(log_path):
        os.makedirs(log_path)


# Function to write log entries
def new_log_entry(message, log_path, serial):
    """
    Appends a new log entry to a log file. The log file is named in the format `log_<serial>.log`
    and is stored in the specified directory. Each log entry includes the current date, time,
    and the provided message.

    :param message: The message to log in the file.
    :type message: str
    :param log_path: The directory where the log file is stored.
    :type log_path: str
    :param serial: A unique identifier used to name the log file.
    :type serial: str
    :return: None
    """
    log_file = os.path.join(log_path, f"log_{serial}.log")
    current_date = datetime.now().strftime("%d-%m-%Y")
    current_time = datetime.now().strftime("%H:%M:%S")
    full_message = f"[{current_date} {current_time}] {message}"
    with open(log_file, "a", encoding="utf-8") as file:
        file.write(full_message + "\n")


# Function to generate authentication headers
def create_auth(header_version, variables):
    """
    Creates an authorization header for API requests by exchanging client credentials
    for an access token.

    This function builds the POST request payload with client credentials and
    sends the request to the specified token URL. If the authentication is
    successful, it returns the headers required for subsequent API requests.

    :param header_version: The version of the API to be used in the request headers.
    :type header_version: str
    :param variables: A dictionary containing authentication and configuration details
                      required for the token exchange and logging.
    :type variables: dict
    :return: A dictionary containing the authorization headers for making API requests.
    :rtype: dict
    """
    headers = {'Content-Type': 'application/x-www-form-urlencoded'}
    body = {
        'grant_type': 'client_credentials',
        'client_id': variables.get('client_id'),
        'client_secret': variables.get('client_secret')
    }
    if 'scope' in variables:
        body['scope'] = variables.get('scope')
    if 'audience' in variables:
        body['audience'] = variables.get('audience')

    try:
        response = requests.post(variables['TOKEN_URL'], headers=headers, data=body)
        response.raise_for_status()
        access_token = response.json()['access_token']
        new_log_entry(f"Successfully received Access Token from {variables['TOKEN_URL']}", variables['log_path'],
                      "auth")
    except Exception as e:
        raise Exception(f"Error in create_auth: {str(e)}")

    return {
        "content-type": "application/json",
        "accept": "text/plain",
        "x-keyfactor-requested-with": "APIClient",
        "x-keyfactor-api-version": f"{header_version}.0",
        "Authorization": f"Bearer {access_token}"
    }


# Function to send HTTP PUT requests
def invoke_http_put(url, header_version, variables, data):
    """
    Sends an HTTP PUT request to the specified URL with the provided headers, variables, and data. Logs the request and
    response details, ensuring that all activities are traceable.

    :param url: The target URL for the HTTP PUT request.
    :type url: str
    :param header_version: The version of the header to be used for the request.
    :type header_version: Any
    :param variables: A dictionary containing metadata and configurations required for the request, such as `log_path`.
    :type variables: dict
    :param data: The JSON-compatible data payload to be sent in the PUT request.
    :type data: dict
    :return: The HTTP response object received after making the PUT request.
    :rtype: requests.Response
    :raises Exception: If there is an error while creating headers, sending the request, or processing the response.
    """
    try:
        headers = create_auth(header_version, variables)
        new_log_entry(f"Sending HTTP PUT request to URL={url} with HeaderVersion={header_version}",
                      variables['log_path'], "put")
        response = requests.put(url, headers=headers, json=data)
        response.raise_for_status()
        new_log_entry(f"Received response from URL={url} with status code {response.status_code}",
                      variables['log_path'], "put")
        return response
    except Exception as e:
        raise Exception(f"Error in invoke_http_put for URL={url}. Error: {str(e)}")


# Function to send HTTP GET requests
def invoke_http_get(url, header_version, variables):
    """
    Sends an HTTP GET request to a specified URL with dynamically created headers and logging of operations.
    This function utilizes authentication headers created based on the provided version and variables.
    Logs both the request initiation and response status to a log file defined in the variables.

    :param url: The target endpoint URL for the HTTP GET request.
    :type url: str
    :param header_version: The version of the authentication header scheme to be used.
    :type header_version: str
    :param variables: A dictionary containing additional configurations and parameters
        required for constructing the headers and logging. Must include 'log_path'.
    :type variables: dict
    :return: The HTTP response object received from the GET request.
    :rtype: requests.models.Response
    :raises Exception: If the request encounters any issues or fails.
    """
    try:
        headers = create_auth(header_version, variables)
        new_log_entry(f"Sending HTTP GET request to URL={url} with HeaderVersion={header_version}",
                      variables['log_path'], "get")
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        new_log_entry(f"Received response from URL={url} with status code {response.status_code}",
                      variables['log_path'], "get")
        return response
    except Exception as e:
        raise Exception(f"Error in invoke_http_get for URL={url}. Error: {str(e)}")


# Function to get certificate ID
def get_certificates(variables, serial):
    """
    Fetches the certificate ID from the API based on the provided serial number.

    This function constructs a query for a certificate's serial number, URL-encodes
    it, and sends an HTTP GET request to retrieve the certificate details from the
    API. After parsing the response, it extracts and returns the certificate ID.

    :param variables: A dictionary containing configuration settings including
        'KEYFACTORAPI' which represents the base URL of the API as a string.
    :param serial: The serial number of the certificate to be fetched.
    :return: The ID of the certificate as retrieved from the API.
    :rtype: Any
    """
    query = f'SerialNumber -eq "{serial}"'
    encoded_query = urllib.parse.quote(query)
    url = f"{variables['KEYFACTORAPI']}/Certificates?QueryString={encoded_query}"
    response = invoke_http_get(url, 1, variables)
    return json.loads(response.text)["Id"]


# Function to check Keyfactor status
def check_keyfactor_status(variables):
    """
    Checks the health status of the Keyfactor API.

    This function sends a GET request to the Keyfactor API's health check URL
    to verify if the service is operational. It invokes the HTTP GET request
    using the provided URL and timeout values obtained from the input
    variables. The function returns ``True`` if the response status code is
    204, indicating the service is healthy.

    :param variables: A dictionary containing the necessary configuration
        values, including the Keyfactor API URL under the 'KEYFACTORAPI' key.
    :type variables: dict

    :return: ``True`` if the health check endpoint returns a 204 status code,
        otherwise ``False``.
    :rtype: bool
    """
    url = f"{variables['KEYFACTORAPI']}/status/healthcheck"
    response = invoke_http_get(url, 1, variables)
    return response.status_code == 204


# Function to get role ID
def get_role_id(variables, line):
    """
    Fetches the role ID for a given role name by constructing a query, sending an HTTP GET request to
    the appropriate endpoint, and decoding the response.

    :param variables: A dictionary containing configuration details such as the API endpoint.
    :type variables: dict
    :param line: A dictionary containing role-related data where the key "role" specifies the role
        name for which the ID is to be retrieved.
    :type line: dict
    :return: The ID of the role that matches the given role name.
    :rtype: int
    """
    query = f'name -eq "{line["role"]}"'
    encoded_query = urllib.parse.quote(query)
    url = f"{variables['KEYFACTORAPI']}/Security/Roles?QueryString={encoded_query}"
    response = invoke_http_get(url, 2, variables)
    return json.loads(response.text)["Id"]


# Function to update certificate owner
def update_certificate_owner(variables, certificate_id, role_id):
    """
    Updates the owner of a certificate by making an HTTP PUT request to the specified endpoint.

    This function utilizes the provided variables dictionary to construct the API endpoint
    URL for updating the certificate owner. It sends the new role information in the
    request body and returns the status code from the server response.

    :param variables: Dictionary containing API configuration details and other relevant
        parameters, including the 'KEYFACTORAPI' entry used to construct the API URL.
    :type variables: dict
    :param certificate_id: Unique identifier of the certificate whose owner is to be updated.
    :type certificate_id: str
    :param role_id: Unique identifier of the new role to be assigned as the owner of the
        certificate.
    :type role_id: str
    :return: HTTP status code of the server response indicating the outcome of the request.
    :rtype: int
    """
    url = f"{variables['KEYFACTORAPI']}/Certificates/{certificate_id}/Owner"
    body = {"NewRoleId": role_id}
    response = invoke_http_put(url, 1, variables, body)
    return response.status_code


def process_line(line, variables):
    """
    Processes a single line of input and updates the certificate ownership by associating
    it with the specified role. Validates the connection to Keyfactor Command, fetches
    certificate and role data, and performs the update operation appropriately. Results
    and errors are logged to the specified log path.

    :param line: A dictionary containing data for processing, specifically:
                 - line['serial']: The serial number of the certificate.
                 - line['role']: The new role to be associated with the certificate.
    :type line: dict
    :param variables: A dictionary containing configuration and runtime variables, such as:
                      - variables['log_path']: Path to log file for storing operation logs.
    :type variables: dict
    :return: None
    :raises Exception: If the connection to Keyfactor Command fails or if any process-specific
                       error occurs. All raised errors are logged.
    """
    try:
        if check_keyfactor_status(variables):
            new_log_entry("Validated connection to Keyfactor Command", variables['log_path'], line['serial'])
        else:
            raise Exception("Failed to validate connection to Keyfactor Command")

        serial = line['serial']
        new_log_entry(f"Getting certificate ID for: {serial}", variables['log_path'], serial)
        certificate_id = get_certificates(variables, serial)

        if certificate_id:
            new_log_entry(f"Certificate ID: {certificate_id}", variables['log_path'], serial)
            new_log_entry(f"Getting role ID for: {line['role']}", variables['log_path'], serial)
            role_id = get_role_id(variables, line)

            if role_id:
                new_log_entry(f"Role ID: {role_id}", variables['log_path'], serial)
                new_log_entry(f"Updating certificate with New Role owner: {line['role']}", variables['log_path'],
                              serial)
                result = update_certificate_owner(variables, certificate_id, role_id)

                if result == 204:
                    new_log_entry(f"Owner updated: {line['role']}", variables['log_path'], serial)
                else:
                    new_log_entry(f"[ERROR] Owner failed to update: {line['role']}", variables['log_path'], serial)
            else:
                new_log_entry(f"[ERROR] Role not found: {line['role']}", variables['log_path'], serial)
        else:
            new_log_entry(f"[ERROR] Certificate not found: {serial}", variables['log_path'], serial)
    except Exception as e:
        new_log_entry(f"Error processing item {line['serial']}: {str(e)}", variables['log_path'], line['serial'])


def main(csv_path, max_threads, variable_file):
    """
    Executes a multithreaded process based on parameters from a CSV file and a variable file.

    This function reads a CSV file and a Python script (variable file) to define the scope
    and context of a multithreaded task. It manages tasks with a specified maximum number
    of threads simultaneously, logs the process execution, and prints the elapsed time
    upon completion.

    :param str csv_path: The path to the CSV file containing the task data.
    :param int max_threads: The maximum number of threads to use for concurrent execution.
    :param str variable_file: The path to the Python script file defining variables and
        configurations for the processing.
    :return: None
    """
    start_time = time.time()
    variables = {}
    with open(variable_file, "r") as file:
        exec(file.read(), variables)

    script_path = os.getcwd()
    log_path = os.path.join(script_path, "RunspaceLogs")
    variables['log_path'] = log_path
    create_log_directory(log_path)

    with open(csv_path, newline='', encoding='utf-8') as csv_file:
        csv_reader = csv.DictReader(csv_file)
        rows = list(csv_reader)

    with ThreadPoolExecutor(max_threads) as executor:
        executor.map(partial(process_line, variables=variables), rows)

    elapsed_time = time.time() - start_time
    print(f"Elapsed time: {elapsed_time:.2f} seconds")
    print(f"All tasks completed using multithreading. Logs created in {log_path}.")

if __name__ == "__main__":
    main()

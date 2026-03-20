from __future__ import annotations
import os
import re
import ipaddress
import jwt
from prettytable import PrettyTable
from .acme_client import *
from .config import load_user_variables
from jwt.algorithms import RSAAlgorithm



def get_oidc_json(oidc_url):
    response = requests.get(oidc_url)
    response.raise_for_status()  # Raise an exception if the request fails
    config = response.json()
    token_url = config.get("token_endpoint")
    jwks_url = config.get("jwks_uri")
    issuer_url = config.get("issuer")
    variables['token_url'] = token_url
    variables['jwks_url'] = jwks_url
    variables['issuer_url'] = issuer_url
    return


def clear_screen():
    try:
        click.clear()  # Attempt to use Click's built-in clear function
    except Exception:
        # Fallback to manually clearing the console using system commands
        if os.name == 'nt':  # For Windows
            os.system('cls')
        else:  # For Linux/Mac
            os.system('clear')


def create_auth_headers(client_id, client_secret):
    token_resp = requests.post(
        variables["token_url"],
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            **({"scope": variables["scope"]} if variables.get("scope") else {}),
            **({"audience": variables["audience"]} if variables.get("audience") else {}),
        },
        timeout=30, verify=variables["cert_check"]
    )
    token_resp.raise_for_status()
    token = token_resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}", 'Content-Type': "application/json"}


def extract_sub_from_token(token):
    # Fetch the JWKS from the URL
    response = requests.get(variables['jwks_url'])
    jwks = response.json()

    # Retrieve the "kid" from the token headers
    headers = jwt.get_unverified_header(token)
    kid = headers["kid"]

    # Find the matching key from the JWKS
    key = next((k for k in jwks["keys"] if k["kid"] == kid), None)
    if not key:
        raise ValueError("Public key for key ID not found.")

    # Convert JWK to PEM
    public_key = RSAAlgorithm.from_jwk(key)

    # Decode the token
    decoded_token = jwt.decode(
        token,
        key=public_key,
        algorithms=["RS256"],
        audience=variables.get("audience"),
        issuer=variables["issuer_url"],
    )

    return decoded_token['sub']


def display_claim_types_and_get_choice():
    click.secho("=== Choose ClaimType ===", fg="cyan")
    click.echo("[1] Role")
    click.echo("[2] Subject")
    click.echo("[3] ClientId")
    click.echo("[4] Exit to Action Menu")
    click.echo("You can only select one ClaimType.")

    choices = click.prompt("Choose which ClaimType to assign to the Claim (1-4)", type=str)

    type_mapping = {
        "1": "role",
        "2": "sub",
        "3": "clientid",
    }
    claim_type = type_mapping[choices] if choices in type_mapping else None
    if claim_type is None:
        click.secho(f"Invalid choice: {choices}. Please try again.", fg="red")
        return
    return claim_type


def display_roles_and_get_choice():
    while True:
        click.clear()
        click.secho("=== Choose Roles ===", fg="cyan")
        click.echo("[1] AccountAdmin")
        click.echo("[2] EnrollmentUser")
        click.echo("[3] SuperAdmin")
        click.echo("[4] Exit to Action Menu")
        click.echo("You can select multiple roles by entering numbers separated by commas (e.g., 1,3).")

        choices = click.prompt("Choose which Roles to assign to the Claim (1-4)", type=str)
        choices = [choice.strip() for choice in choices.split(",")]

        roles_mapping = {
            "1": "AccountAdmin",
            "2": "EnrollmentUser",
            "3": "SuperAdmin",
        }
        roles = []
        for choice in choices:
            if choice == "4":  # Exit case
                click.secho("Exiting to Claims Menu...", fg="cyan")
                return
            elif choice in roles_mapping:
                roles.append(roles_mapping[choice])
            else:
                click.secho(f"Invalid choice: {choice}. Please try again.", fg="red")
                return
        roles = list(set(roles))
        return roles


def display_templates_and_get_choice(templates):
    print(f"{'ID':<10}{'TemplateName':<20}")
    print("-" * 30)
    for template in templates:
        print(f"{template['Id']:<10}{template['Name']:<20}")
    print("-" * 30)

    template_choice = input(
        "Enter the ID of the Keyfactor Enrollment Pattern to associate with this claim or press Enter to return: ").strip()
    if not template_choice:
        click.secho("No pattern selected. Returning...", fg="red")
        sleep(2)
        return

    selected_template = next((template for template in templates if template["Id"] == int(template_choice)), None)
    if selected_template:
        # Return the TemplateName of the selected template
        return selected_template["Name"]
    else:
        click.secho("Invalid ID entered. Please try again.", fg="red")
        sleep(2)
        return


def update_claim():
    while True:
        claims = (acme_client.claim_get()).json()
        if not claims:
            click.secho("No claims found", fg="red")
            return
        from prettytable import PrettyTable
        table = PrettyTable()
        table.field_names = claims[0].keys()
        for claim in claims:
            table.add_row(claim.values())
        print(table)
        click.secho("Only claim Roles and Template can be updated")
        choice_claim_id = input("Enter a Claim Id to Update: ")
        matching_claim = next((claim for claim in claims if str(claim.get("id")) == str(choice_claim_id)), None)
        while True:
            click.clear()
            click.secho("=== Update Claim Menu ===", fg="cyan")
            click.echo("[1] Role")  # done
            click.echo("[2] Template")  # done
            click.echo("[3] Update Claim")

            choice = click.prompt("Choose which catagory you want to update (1-3)", type=int)

            if choice == 1:
                roles = display_roles_and_get_choice()
                if roles:
                    matching_claim["roles"] = roles
                    if 'EnrollmentUser' in roles:
                        templates = (acme_client.template_patterns_get()).json()
                        template = display_templates_and_get_choice(templates)
                        if template:
                            matching_claim["template"] = template
            elif choice == 2:
                templates = (acme_client.template_patterns_get()).json()
                template = display_templates_and_get_choice(templates)
                if template:
                    matching_claim["template"] = template
            result = acme_client.claim_put(matching_claim['id'], matching_claim)
            print(result.text)
            if result.status_code == 200:
                click.secho(f"Claim: {matching_claim['claimValue']} was updated successfully")
                sleep(2)
                return
            else:
                click.secho(result.text)
                sleep(2)
                return


def remove_claim():
    while True:
        claims = (acme_client.claim_get()).json()
        if not claims:
            click.secho("No claims found", fg="red")
            return
        from prettytable import PrettyTable
        table = PrettyTable()
        table.field_names = claims[0].keys()
        for claim in claims:
            table.add_row(claim.values())
        print(table)
        choice_claim_id = input("Enter the ID of the claim to remove: ")
        matching_claim = next((claim for claim in claims if str(claim.get("id")) == str(choice_claim_id)), None)
        if matching_claim:
            claim_id = matching_claim['id']
            click.secho(f"Removing claim: {matching_claim['claimValue']}")
            delete = acme_client.claim_delete(claim_id)
            if delete.status_code == 204:
                click.secho(f"Claim with ID {claim_id} removed successfully.")
                sleep(2)
                return
        else:
            click.secho(f"Claim with ID {choice_claim_id} not found.")
            sleep(2)
            return


def show_claims():
    claims = (acme_client.claim_get()).json()
    if not claims:
        click.secho("No claims found", fg="red")
        return
    from prettytable import PrettyTable
    table = PrettyTable()
    table.field_names = claims[0].keys()
    for claim in claims:
        table.add_row(claim.values())
    print(table)
    input("Press Enter to continue...")


def add_claim():
    while True:
        roles = display_roles_and_get_choice()
        print(roles)
        claim_type = display_claim_types_and_get_choice()
        print(claim_type)
        click.secho("=== Enter ClaimValue ===", fg="cyan")
        claim_value = click.prompt("Enter the ClaimValue to assign to the Claim", type=str)
        print(claim_value)
        body = {
            "ClaimType": claim_type,
            "ClaimValue": claim_value,
            "Roles": roles
        }
        template = None
        if 'EnrollmentUser' in roles:
            templates = (acme_client.template_patterns_get()).json()
            template = display_templates_and_get_choice(templates)
            if template:
                body["Template"] = template

        result = acme_client.claim_post(body)
        if result.status_code == 200:
            click.secho(f"Claim: {claim_value} was added successfully")
            sleep(2)
            return
        else:
            click.secho(result.text)
            sleep(2)
            return


def show_identifiers():
    response = acme_client.identifier_get()
    identifiers = json.loads(response.text)
    print(identifiers)
    for idx, claim in enumerate(identifiers, start=1):
        claim["Index"] = idx
    table = PrettyTable()
    field_names = ["Index"] + [key for key in identifiers[0].keys() if key != "Index"]
    table.field_names = field_names
    for claim in identifiers:
        table.add_row([claim[field] for field in table.field_names])
    print(table)
    input("Press Enter to continue...")
    return


def add_identifier():
    def _is_valid_fqdn(domain):
        # Regex pattern for FQDN validation
        fqdn_regex = r'^(?=.{1,253}$)(?!-)[a-zA-Z0-9-]{1,63}(?<!-)(\.[a-zA-Z]{2,})+$'
        return re.match(fqdn_regex, domain) is not None

    def _is_valid_subnet(subnet):
        try:
            ipaddress.ip_network(subnet, strict=False)
            return True
        except ValueError:
            return False

    def _is_valid_regex(pattern):
        try:
            re.compile(pattern)
            return True
        except re.error:
            return False

    def _is_valid_wildcard_domain(domain):
        wildcard_pattern = r'^\*\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$'
        if not re.match(wildcard_pattern, domain):
            return False
        fqdn_part = domain[2:]  # Remove '*.'
        fqdn_regex = r'^(?!-)[a-zA-Z0-9-]{1,63}(?<!-)(\.[a-zA-Z]{2,})+$'
        if not re.match(fqdn_regex, fqdn_part):
            return False
        return True

    while True:
        click.clear()
        click.secho("=== Identifier Main Menu ===", fg="cyan")
        click.echo("[1] Fqdn EX(appsrvr12.keyexample.com)")  # done
        click.echo("[2] Regex EX([a-zA-Z0-9]+.keyexample.com)")  # done
        click.echo("[3] Subnet EX(192.168.12.0/24 or 2001:db8:abcd::/48)")  # dome
        click.echo("[4] Wildcard EX(*.keyexample.com)")  # dome
        click.echo("[5] Exit to previous menu")  # done

        choice = click.prompt("Choose the Identifier Type (1-5)", type=int)

        identifier = None
        itype = None
        if choice == 1:
            identifier = input("Enter the FQDN")
            itype = "Fqdn"
            if not _is_valid_fqdn(identifier):
                click.secho(f"Invalid FQDN: {identifier}", fg="red")
                sleep(2)
                add_identifier()
                return
        elif choice == 2:
            identifier = input("Enter the Regex (not Validated)")
            itype = "Regex"
            if not _is_valid_regex(identifier):
                click.secho(f"Invalid Regex: {identifier}", fg="red")
                sleep(2)
                add_identifier()
                return
        elif choice == 3:
            identifier = input("Enter the Subnet (not Validated)")
            type = "Subnet"
            if not _is_valid_subnet(identifier):
                click.secho(f"Invalid Regex: {identifier}", fg="red")
                sleep(2)
                add_identifier()
                return
        elif choice == 4:
            identifier = input("enter wildcard domain (must be enable in the system settings)")
            type = "Wildcard"
            if not _is_valid_wildcard_domain(identifier):
                click.secho(f"Invalid Wildcard Domain: {identifier}", fg="red")
                sleep(2)
                add_identifier()
        elif choice == 5:
            click.secho("Exiting to previous menu...", fg="cyan")
            return

        body = {
            "Identifier": identifier,
            "type": itype
        }
        result = acme_client.identifier_add_post(body)
        if result.status_code == 200:
            click.secho(f"Identifier: {identifier} was added successfully")
            sleep(2)
            identifiers_menu()
        else:
            click.secho(result.text)
            sleep(2)
            identifiers_menu()


def remove_identifier():
    while True:
        response = acme_client.identifier_get()
        identifiers = json.loads(response.text)
        for idx, claim in enumerate(identifiers, start=1):
            claim["Index"] = idx
        table = PrettyTable()
        field_names = ["Index"] + [key for key in identifiers[0].keys() if key != "Index"]
        table.field_names = field_names
        for claim in identifiers:
            table.add_row([claim[field] for field in table.field_names])
        print(table)
        choice = click.prompt("Choose an index to remove", type=int)
        if not any(claim["Index"] == choice for claim in identifiers):
            click.secho(f"Invalid Choice. The is no index value of {choice}.", fg="red")
            click.pause()
        else:
            matching_identifier = next((claim for claim in identifiers if str(claim.get("Index")) == str(choice)), None)
            result = acme_client.identifier_delete(matching_identifier['id'])
            if result.status_code == 204:
                click.secho(f"Identifier with ID {matching_identifier['id']} removed successfully.")
                sleep(2)
                return
            else:
                click.secho(result.text)
                sleep(2)
                return


def claims_menu():
    """Present the Action Main Menu and handle user choices."""
    while True:
        click.clear()
        click.secho("=== Action Main Menu ===", fg="cyan")
        click.echo("[1] Show Claims")  # done
        click.echo("[2] Add Claim")  # done
        click.echo("[3] Update Claim")
        click.echo("[4] Remove Claim")  # dome
        click.echo("[5] Exit to Main Menu")  # done

        choice = click.prompt("Choose what action you want to execute (1-5)", type=int)

        if choice == 1:
            show_claims()
        elif choice == 2:
            add_claim()
        elif choice == 3:
            update_claim()
        elif choice == 4:
            remove_claim()
        elif choice == 5:
            click.secho("Exiting to Main Menu...", fg="cyan")
            return
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 5.", fg="red")
            click.pause()


def identifiers_menu():
    while True:
        click.clear()
        click.secho("=== Identifier Main Menu ===", fg="cyan")
        click.echo("[1] Show Identifiers")
        click.echo("[2] Add Identifiers")
        click.echo("[3] Remove Identifiers")
        click.echo("[4] Exit to Main Menu")

        choice = click.prompt("Choose what action you want to execute (1-5)", type=int)

        if choice == 1:
            show_identifiers()  # done
        elif choice == 2:
            add_identifier()
        elif choice == 3:
            remove_identifier()
        elif choice == 4:
            click.secho("Exiting to Main Menu...", fg="cyan")
            return


def eab_keys():
    client_id = input("Enter the Client ID: ")
    client_secret = input("Enter the Secret: ")
    clear_screen()
    try:
        headers = create_auth_headers(client_id, client_secret)
        templates = (acme_client.template_patterns_get()).json()
        template = display_templates_and_get_choice(templates)
        result = acme_client.key_management_get(template, headers)
        click.secho(result.text, fg="green")
        sleep(5)
        return
    except Exception as e:
        click.secho(f"Error: {e}", fg="red")


def get_sub():
    client_id = input("Enter the Client ID: ")
    client_secret = input("Enter the Secret: ")
    clear_screen()
    headers = create_auth_headers(client_id, client_secret)
    auth_header = headers.get("Authorization")  # Get the Authorization header
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split("Bearer ")[1]  # Extract everything after 'Bearer '
        sub = extract_sub_from_token(token)
        click.secho(f"extracted subject: {sub}", fg="green")
        sleep(5)
        return
    else:
        print("No valid Authorization header or token found.")
        sleep(2)
        return


def admin():
    while True:
        click.clear()
        click.secho("=== Administration Menu ===", fg="cyan")
        click.echo("[1] Claims")
        click.echo("[2] Identifiers")
        click.echo("[3] Get EAB Keys")
        click.echo("[4] Get claim Subject")
        click.echo("[5] Exit")

        choice = click.prompt("Choose what action you want to execute (1-4)", type=int)

        if choice == 1:
            claims_menu()
        elif choice == 2:
            identifiers_menu()
        elif choice == 3:
            eab_keys()
        elif choice == 4:
            get_sub()
        elif choice == 5:
            click.secho("Exiting", fg="cyan")
            exit(0)
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 4.", fg="red")
            click.pause()


def account():
    while True:
        click.clear()
        click.secho("=== Account Admin ===", fg="cyan")
        click.echo("[1] Claims")  # done
        click.echo("[2] Get EAB Keys")  # done
        click.echo("[3] Get claim Subject")  # done
        click.echo("[4] Exit")

        choice = click.prompt("Choose what action you want to execute (1-4)", type=int)

        if choice == 1:
            claims_menu()
        elif choice == 2:
            eab_keys()
        elif choice == 3:
            get_sub()
        elif choice == 4:
            click.secho("Exiting", fg="cyan")
            exit(0)
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 4.", fg="red")
            click.pause()


def user():
    """Present the Main Menu and handle user choices."""
    click.secho("Enrollment User", fg="bright_green")
    while True:
        click.clear()
        click.secho("=== Enrollment User Menu ===", fg="cyan")
        click.echo("[1] Get EAB Keys")
        click.echo("[2] Get claim Subject")
        click.echo("[3] Exit")

        choice = click.prompt("Choose what action you want to execute (1-3)", type=int)

        if choice == 1:
            eab_keys()  # done
        elif choice == 2:
            get_sub()
        elif choice == 3:
            click.secho("Exiting", fg="cyan")
            exit(0)
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 4.", fg="red")
            click.pause()


@click.command()
def main_menu(base_path: str = "."):
    # load global variable
    global variables
    global acme_client

    # load Variables
    variables = load_user_variables(base_path)

    # validate Required Varioables
    REQUIRED = ["scope", "audience", "oidc_discovery_url", "acme_dns", "keyfactor_dns", "cert_check"]
    missing = [k for k in REQUIRED if not variables.get(k)]
    if missing:
        raise ValueError(f"Missing required config keys in variables.py: {', '.join(missing)}")

    # Load OIDC Variales
    get_oidc_json(variables['oidc_discovery_url'])

    # load acme client class
    acme_client = AcmeClient(variables)

    if not variables['client_id']:
        variables['client_id'] = click.prompt("Enter OIDC Client ID", type=str)
    if not variables['client_secret']:
        variables['client_secret'] = click.prompt("Enter OIDC Client Secret", type=str)
    click.echo("Validating Access Token...")
    if not create_auth_headers(variables['client_id'], variables['client_secret']):
        click.echo("Failed to create Authorization Token")
        exit(1)
    click.echo("Determining ACME role level")
    try:
        if acme_client.app_settings_get():
            admin()
        elif acme_client.admin_accounts_get():
            account()
        else:
            user()
    finally:
        click.secho("could not determine acme role. Exiting...", fg="cyan")

if __name__ == "__main__":
    main_menu()
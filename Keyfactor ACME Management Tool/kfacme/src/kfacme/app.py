from __future__ import annotations
import os
import re
import ipaddress
import jwt
from prettytable import PrettyTable
from .acme_client import *
from .config import load_user_variables
from getpass import getpass
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
    try:
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
    except requests.RequestException as e:
        click.secho(f"Error creating authentication headers, Please check your credentials", fg="red")
        return None


def extract_sub_from_token(token):
    decoded_token = jwt.decode(
        token,
        options={
            "verify_signature": False,
            "verify_exp": False,
            "verify_nbf": False,
            "verify_iat": False,
            "verify_aud": False,
            "verify_iss": False,
            "verify_sub": False,
            "verify_jti": False,
        },
        algorithms=["RS256"],
    )

    sub = decoded_token.get("sub")
    if not sub:
        click.echo("Decoded token does not contain 'sub'.")
        return None
    return sub


def display_claim_types_and_get_choice():
    click.secho("=== Choose ClaimType ===", fg="cyan")
    click.echo("[1] Role")
    click.echo("[2] Subject")
    click.echo("[3] Client Id")
    click.echo("[4] Exit to Action Menu")
    click.echo("You can only select one ClaimType.")

    choices = click.prompt(
        "Choose which ClaimType to assign to the Claim (1-4)",
        type=str,
        default="",
        show_default=False,
    ).strip()

    if not choices:
        click.secho("No ClaimType selected. Returning...", fg="yellow")
        return None

    type_mapping = {
        "1": "role",
        "2": "sub",
        "3": "clientid",
    }
    claim_type = type_mapping[choices] if choices in type_mapping else None
    if not claim_type:
        click.secho(f"Invalid choice: {choices}.", fg="red")
        return
    return claim_type


def display_roles_and_get_choice():
    click.clear()
    click.secho("=== Choose Roles ===", fg="cyan")
    click.echo("[1] AccountAdmin")
    click.echo("[2] EnrollmentUser")
    click.echo("[3] SuperAdmin")
    click.echo("[4] Exit to Action Menu")
    click.echo("You can select multiple roles by entering numbers separated by commas (e.g., 1,3).")

    choices = click.prompt(
        "Choose which Roles to assign to the Claim (1-4)",
        type=str,
        default="",
        show_default=False,
    ).strip()

    if not choices:
        click.secho("No role selected. Returning...", fg="yellow")
        return None

    roles_mapping = {
        "1": "AccountAdmin",
        "2": "EnrollmentUser",
        "3": "SuperAdmin",
    }

    roles = []
    for choice in [c.strip() for c in choices.split(",")]:
        if choice == "4":
            click.secho("Exiting to Claims Menu...", fg="cyan")
            return None
        if choice not in roles_mapping:
            click.secho(f"Invalid choice: {choice}.", fg="red")
            return None
        roles.append(roles_mapping[choice])

    return list(dict.fromkeys(roles))


def display_accounts_and_get_choice(accounts):
    if not accounts:
        click.secho("No accounts found.", fg="red")
        sleep(2)
        return

    for idx, claim in enumerate(accounts, start=1):
        claim["Index"] = idx

    table = PrettyTable()
    field_names = ["Index"] + [key for key in accounts[0].keys() if key != "Index"]
    table.field_names = field_names

    for claim in accounts:
        table.add_row([claim.get(field, "") for field in table.field_names])

    print(table)

    account_choice = input(
        "Enter the Index User ID of the Keyfactor ACME account you want to change or press Enter to return: "
    ).strip()

    if not account_choice:
        click.secho("No account selected. Returning...", fg="red")
        sleep(2)
        return None

    selected_account = next((account for account in accounts if account.get("Index") == int(account_choice)), None)
    if selected_account:
        if selected_account.get("status") == "revoked":
            click.secho(f"Account {selected_account.get('accountId')} is revoked. Please select another account.",
                        fg="red")
            sleep(2)
            return display_accounts_and_get_choice(accounts)
        return selected_account["accountId"]
    else:
        click.secho("Invalid ID entered. Please try again.", fg="red")
        sleep(2)
        return


def display_templates_and_get_choice(templates):
    print(f"{'ID':<10}{'Template Name':<20}{'Pattern Name':<20}")
    print("-" * 50)
    for template in templates:
        template_name = template.get("Template", {}).get("TemplateName", "")
        print(f"{template['Id']:<10}{template_name:<20}{template.get('Name', ''):<20}")
    print("-" * 50)

    template_choice = input(
        "Enter the ID of the Certificate Template to associate with this claim or press Enter to return: ").strip()
    if not template_choice:
        click.secho("No template selected. Returning...", fg="red")
        sleep(2)
        return None

    selected_template = next((template for template in templates if template["Id"] == int(template_choice)), None)
    if selected_template:
        return selected_template.get("Template", {}).get("CommonName")
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
        table = PrettyTable()
        table.field_names = claims[0].keys()
        for claim in claims:
            table.add_row(claim.values())
        print(table)
        click.secho("Only Claim Roles and Template can be updated")
        choice_claim_id = input("Enter a Claim Id to Update: ")
        if not choice_claim_id.isdigit():
            click.secho("No Claim IS Selected, Returning to previous menu", fg="red")
            sleep(2)
            claims_menu()
        if not any(claim["id"] == int(choice_claim_id) for claim in claims):
            click.secho(f"Invalid Claim Id. There is no claim with ID {choice_claim_id}.", fg="red")
            update_claim()
        matching_claim = next((claim for claim in claims if str(claim.get("id")) == str(choice_claim_id)), None)
        while True:
            click.secho("=== Update Claim Menu ===", fg="cyan")
            click.echo("[1] Role")
            click.echo("[2] Template")
            click.echo("[3] return to claims menu")

            choice = click.prompt("Choose which category you want to update (1-3)", default="", type=int)

            if choice == 1:
                roles = display_roles_and_get_choice()
                if not roles:
                    click.secho("No roles selected. Returning to Update Claim Menu...", fg="yellow")
                    continue

                matching_claim["roles"] = roles
                if 'EnrollmentUser' in roles:
                    templates = (acme_client.template_patterns_get()).json()
                    template = display_templates_and_get_choice(templates)
                    if template is None:
                        update_claim()
                    if template:
                        matching_claim["template"] = template

            elif choice == 2:
                templates = (acme_client.template_patterns_get()).json()
                template = display_templates_and_get_choice(templates)
                if template is None:
                    update_claim()
                if template:
                    matching_claim["template"] = template

            elif choice == 3:
                click.secho("Exiting to claims menu...", fg="cyan")
                claims_menu()

            else:
                click.secho("Invalid choice. Please try again.", fg="red")
                sleep(2)
                return

            result = acme_client.claim_put(matching_claim['id'], matching_claim)
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
        table = PrettyTable()
        table.field_names = claims[0].keys()
        for claim in claims:
            table.add_row(claim.values())
        print(table)
        choice_claim_id = input("Enter the ID of the claim to remove: ")
        matching_claim = next((claim for claim in claims if str(claim.get("id")) == str(choice_claim_id)), None)
        if matching_claim:
            claim_id = matching_claim['id']
            delete = acme_client.claim_delete(claim_id)
            if delete.status_code == 204:
                click.secho(f"Claim with ID {claim_id} removed successfully.")
                sleep(2)
                return
            else:
                click.secho(f"Failed to remove claim with ID {claim_id}.")
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
    table = PrettyTable()
    table.field_names = claims[0].keys()
    for claim in claims:
        table.add_row(claim.values())
    print(table)
    input("Press Enter to continue...")


def add_claim():
    roles = display_roles_and_get_choice()
    if not roles:
        click.secho("No roles selected. Returning to Claims Menu...", fg="yellow")
        sleep(2)
        return

    claim_type = display_claim_types_and_get_choice()
    if not claim_type:
        click.secho("No claim type selected. Returning to Claims Menu...", fg="yellow")
        sleep(2)
        return

    click.secho("=== Enter Claim Value ===", fg="cyan")
    claim_value = click.prompt("Enter the Claim Value to assign to the Claim", type=str)
    body = {
        "ClaimType": claim_type,
        "ClaimValue": claim_value,
        "Roles": roles
    }
    template = None
    if 'EnrollmentUser' in roles:
        templates = (acme_client.template_patterns_get()).json()
        template = display_templates_and_get_choice(templates)
        if template is None:
            add_claim()
        if template:
            body["Template"] = template
    print(body)
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
    if not identifiers:
        click.secho("No identifiers found", fg="red")
        return
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
    def _is_wildcard_enabled():
        result = acme_client.app_settings_get()
        settings = json.loads(result.text)
        wildcard_setting = next(
            (setting for setting in settings if setting.get("name") == "Allow Wildcard Enrollments"), None)
        if not wildcard_setting: return False
        return str(wildcard_setting.get("value", "")).lower() == "true"

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
        return re.match(fqdn_regex, fqdn_part) is not None

    while True:
        click.clear()
        click.secho("=== Identifier Main Menu ===", fg="cyan")
        click.echo("[1] FQDN EX(appsrvr12.keyexample.com)")
        click.echo("[2] Regex EX([a-zA-Z0-9]+.keyexample.com)")
        click.echo("[3] Subnet EX(192.168.12.0/24 or 2001:db8:abcd::/48)")
        click.echo("[4] Wildcard EX(*.keyexample.com)")
        click.echo("[5] Exit to previous menu")

        choice = click.prompt("Choose the Identifier Type (1-5)", default="", type=int)

        identifier = None
        itype = None

        if choice == 1:
            identifier = input("Enter the FQDN: ").strip()
            itype = "fqdn"
            if not _is_valid_fqdn(identifier):
                click.secho(f"Invalid FQDN: {identifier}", fg="red")
                sleep(2)
                continue

        elif choice == 2:
            identifier = input("Enter the Regex: ").strip()
            itype = "Regex"
            if not _is_valid_regex(identifier):
                click.secho(f"Invalid Regex: {identifier}", fg="red")
                sleep(2)
                continue

        elif choice == 3:
            identifier = input("Enter the Subnet (ipv4 or IPv6 CIDR: ").strip()
            itype = "Subnet"
            if not _is_valid_subnet(identifier):
                click.secho(f"Invalid Subnet: {identifier}", fg="red")
                sleep(2)
                continue

        elif choice == 4:
            if not _is_wildcard_enabled():
                click.secho("Wildcard enrollment is not enabled in system settings.", fg="red")
                sleep(2)
                continue
            identifier = input("Enter wildcard domain (must be enabled in system settings): ").strip()
            itype = "Wildcard"
            if not _is_valid_wildcard_domain(identifier):
                click.secho(f"Invalid Wildcard Domain: {identifier}", fg="red")
                sleep(2)
                continue

        elif choice == 5:
            click.secho("Exiting to previous menu...", fg="cyan")
            return

        else:
            click.secho("Invalid choice. Please enter a number between 1 and 5.", fg="red")
            sleep(2)
            continue

        body = {
            "Identifier": identifier,
            "type": itype
        }

        try:
            result = acme_client.identifier_add_post(body)
            if result.status_code == 200:
                click.secho(f"Identifier '{identifier}' was added successfully", fg="green")
                sleep(2)
                return
            else:
                click.secho(f"Server rejected the request ({result.status_code})", fg="red")
                click.echo(result.text)
                sleep(2)
                continue

        except requests.HTTPError as e:
            try:
                if e.response is not None:
                    click.echo(e.response.text)
            except Exception:
                pass
            sleep(2)
            continue
        except requests.RequestException as e:
            click.secho(f"Network/API error while adding identifier: {e}", fg="red")
            sleep(2)
            continue


def remove_identifier():
    response = acme_client.identifier_get()
    identifiers = json.loads(response.text)
    if not identifiers:
        click.secho("No identifiers found", fg="red")
        return
    for idx, claim in enumerate(identifiers, start=1):
        claim["Index"] = idx
    table = PrettyTable()
    field_names = ["Index"] + [key for key in identifiers[0].keys() if key != "Index"]
    table.field_names = field_names
    for claim in identifiers:
        table.add_row([claim[field] for field in table.field_names])
    print(table)
    choice = input("Choose an index to remove (press Enter to go back): ").strip()
    if not choice: return
    if not choice.isdigit():
        click.secho("Invalid choice. Please enter a number.", fg="red")
        sleep(2)
        return remove_identifier()
    choice = int(choice)
    if not any(claim["Index"] == choice for claim in identifiers):
        click.secho(f"Invalid choice. There is no index value of {choice}.", fg="red")
        remove_identifier()
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


def show_accounts():
    response = acme_client.admin_accounts_get()
    accounts = json.loads(response.text)

    if not accounts:
        click.secho("No accounts found", fg="red")
        return

    for idx, claim in enumerate(accounts, start=1):
        claim["Index"] = idx

    table = PrettyTable()

    # Build a stable set of columns across all account records
    field_names = ["Index"]
    seen = {"Index"}
    for claim in accounts:
        for key in claim.keys():
            if key not in seen:
                seen.add(key)
                field_names.append(key)

    table.field_names = field_names

    # Use .get() so missing keys render as blank instead of crashing
    for claim in accounts:
        table.add_row([claim.get(field, "") for field in table.field_names])

    print(table)
    input("Press Enter to continue...")
    return


def change_template():
    response = acme_client.admin_accounts_get()
    accounts = json.loads(response.text)
    if not accounts:
        click.secho("No accounts found", fg="red")
        return
    id = display_accounts_and_get_choice(accounts)
    if id is None:
        return
    template = display_templates_and_get_choice((acme_client.template_patterns_get()).json())
    if template is None:
        change_template()
    data = {
        "template": template
    }
    acme_client.admin_accounts_put(id, data)
    return


def eab_keys(client_id:str = None, client_secret:str = None):
    if not client_id:
        client_id = input("Enter the Client ID (press enter pr return to the previous menu): ").strip()
        if not client_id:
            click.secho("No Client ID entered. Returning to previous menu...", fg="yellow")
            sleep(2)
            return sub_menu()

    if not client_secret:
        client_secret = getpass("Enter the Client Secret (press enter pr return to the previous menu) ").strip()
        if not client_secret:
            click.secho("No Secret entered. Returning to previous menu...", fg="yellow")
            sleep(2)
            return sub_menu()
    clear_screen()
    try:
        headers = create_auth_headers(client_id, client_secret)
        templates = (acme_client.template_patterns_get()).json()
        if not templates:
            click.secho("No templates found", fg="red")
            return sub_menu()
        click.secho("Select the template associated with your Account")
        template = display_templates_and_get_choice(templates)
        result = acme_client.key_management_get(template, headers)
        click.secho(result.text, fg="green")
        sleep(5)
        return sub_menu()
    except Exception as e:
        click.secho("You do not have access to EAB keys for that template.  Please try again", fg="red")
        return sub_menu()


def delete_eab_keys():
    response = acme_client.admin_accounts_get()
    accounts = json.loads(response.text)
    if not accounts:
        click.secho("No accounts found", fg="red")
        return sub_menu()
    id = display_accounts_and_get_choice(accounts)
    if id is None:
        return sub_menu()
    click.secho(f"Are you sure you want to delete the account with ID {id}?", fg="red")
    click.secho("This action cannot be undone.", fg="red")
    click.secho("Press Enter to continue or Ctrl+C to exit.", fg="red")

    result = acme_client.admin_accounts_revoke_post(id, True)
    if result:
        click.secho(f"Account with ID {id} deleted successfully", fg="green")
    else:
        click.secho(f"Failed to delete account with ID {id}", fg="red")


def show_system_settings():
    result = acme_client.app_settings_get()
    settings = json.loads(result.text)
    if not settings:
        click.secho("No settings  found", fg="red")
        return

    table = PrettyTable()
    table.field_names = ["id", "name", "value"]

    for setting in settings:
        table.add_row([
            setting.get("id", ""),
            setting.get("name", ""),
            setting.get("value", ""),
        ])

    print(table)
    click.pause()
    input("Press Enter to continue...")


def change_setting(s):
    result = acme_client.app_settings_get()
    settings = json.loads(result.text)

    if not settings:
        click.secho("No settings found", fg="red")
        return

    setting_map = {
        "wildcard_allow": {
            "name": "Allow Wildcard Enrollments",
            "desired_value": "True",
            "already_msg": "Wildcard Enrollments are already allowed",
        },
        "wildcard_deny": {
            "name": "Allow Wildcard Enrollments",
            "desired_value": "False",
            "already_msg": "Wildcard Enrollments are already denied",
        },
        "revocation_enabled": {
            "name": "Certificate Revocation Enabled",
            "desired_value": "True",
            "already_msg": "Certificate Revocation is already enabled",
        },
        "revocation_disabled": {
            "name": "Certificate Revocation Enabled",
            "desired_value": "False",
            "already_msg": "Certificate Revocation is already disabled",
        },
    }

    config = setting_map.get(s)
    if not config:
        click.secho("Invalid setting", fg="red")
        return

    target = next(
        (setting for setting in settings if setting.get("name") == config["name"]),
        None
    )

    if not target:
        click.secho(f"Setting '{config['name']}' not found", fg="red")
        return

    current_value = str(target.get("value", "")).lower()
    desired_value = config["desired_value"].lower()

    if current_value == desired_value:
        click.secho(config["already_msg"], fg="red")
        sleep(2)
        return

    body = {"value": config["desired_value"]}

    result = acme_client.app_settings_put(target["id"], body)
    if result.status_code == 204:
        click.secho(f"Setting {s} was changed successfully")
        show_system_settings()
        system_settings_menu()

    else:
        click.secho(f"Setting {s} change failed", fg="red")


def get_sub(client_id:str = None, client_secret:str = None):
    if not client_id:
        client_id = input("Enter the Client ID (press enter or return to the previous menu): ").strip()
        if not client_id:
            click.secho("No Client ID entered. Returning to previous menu...", fg="yellow")
            sleep(2)
            return sub_menu()
    if not client_secret:
        client_secret = input("Enter the Client Secret (press enter or return to the previous menu): ").strip()
        if not client_secret:
            click.secho("No Secret entered. Returning to previous menu...", fg="yellow")
            sleep(2)
            return sub_menu()
    clear_screen()
    headers = create_auth_headers(client_id, client_secret)
    if not headers:
        click.secho("Invalid Client ID or Secret. Please try again.", fg="red")
        return sub_menu()
    auth_header = headers.get("Authorization")  # Get the Authorization header
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split("Bearer ")[1]  # Extract everything after 'Bearer '
        sub = extract_sub_from_token(token)
        click.secho(f"Extracted subject: {sub}", fg="green")
        click.secho("Press Enter to continue...", fg="green")
        click.pause()
        return sub_menu()
    else:
        click.secho("No valid Authorization header or token found.", fg="red")
        sleep(2)
        return sub_menu()


def system_settings_menu():
    while True:
        click.secho("=== System Setting Main Menu ===", fg="cyan")
        click.echo("[1] Show Settings")
        click.echo("[2] Allow Wildcard Enrollments")
        click.echo("[3] Deny Wildcard Enrollments")
        click.echo("[4] Certificate Revocation Enabled")
        click.echo("[5] Certificate Revocation Disabled")
        click.echo("[6] Exit to Main Menu")

        choice = click.prompt("Choose what action you want to execute (1-6)", type=int)

        if choice == 1:
            show_system_settings()
        elif choice == 2:
            change_setting('wildcard_allow')
        elif choice == 3:
            change_setting('wildcard_deny')
        elif choice == 4:
            change_setting('revocation_enabled')
        elif choice == 5:
            change_setting('revocation_disabled')
        elif choice == 6:
            click.secho("Exiting to Main Menu...", fg="cyan")
            return sub_menu()


def change_template_mapping_menu():
    while True:
        click.clear()
        click.secho("=== Change Template Menu ===", fg="cyan")
        click.echo("[1] Show accounts")
        click.echo("[2] change template mapping")
        click.echo("[3] Exit to Main Menu")

        choice = click.prompt(
            "Choose what action you want to execute (1-3)",
            type=str,
            default="",
            show_default=False,
        ).strip()

        if not choice:
            click.secho("Returning to Main Menu...", fg="cyan")
            return sub_menu()

        if not choice.isdigit():
            click.secho("Invalid choice. Please enter a number between 1 and 5.", fg="red")
            click.pause()
            continue

        choice = int(choice)
        if choice == 1:
            show_accounts()
        elif choice == 2:
            change_template()
        elif choice == 3:
            click.secho("Exiting to Main Menu...", fg="cyan")
            return sub_menu()


def claims_menu():
    """Present the Action Main Menu and handle user choices."""
    while True:
        click.clear()
        click.secho("=== Claims Menu ===", fg="cyan")
        click.echo("[1] Show Claims")
        click.echo("[2] Add Claim")
        click.echo("[3] Update Claim")
        click.echo("[4] Remove Claim")
        click.echo("[5] Exit to Main Menu")

        choice_raw = click.prompt(
            "Choose what action you want to execute (1-5) or press Enter to return",
            type=str,
            default="",
            show_default=False,
        ).strip()

        if not choice_raw:
            click.secho("Returning to Main Menu...", fg="cyan")
            return sub_menu()

        if not choice_raw.isdigit():
            click.secho("Invalid choice. Please enter a number between 1 and 5.", fg="red")
            click.pause()
            continue

        choice = int(choice_raw)

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
            return sub_menu()
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

        choice_raw = click.prompt(
            "Choose what action you want to execute (1-4) or press Enter to return",
            type=str,
            default="",
            show_default=False,
        ).strip()

        if not choice_raw:
            click.secho("Returning to Main Menu...", fg="cyan")
            return sub_menu()

        if not choice_raw.isdigit():
            click.secho("Invalid choice. Please enter a number between 1 and 4.", fg="red")
            click.pause()
            continue

        choice = int(choice_raw)

        if choice == 1:
            show_identifiers()
        elif choice == 2:
            add_identifier()
        elif choice == 3:
            remove_identifier()
        elif choice == 4:
            click.secho("Exiting to Main Menu...", fg="cyan")
            return sub_menu()
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 4.", fg="red")
            click.pause()


def admin():
    while True:
        click.clear()
        click.secho("=== Administration Menu ===", fg="cyan")
        click.echo("[1] Get claim Subject")
        click.echo("[2] Get EAB Keys")
        click.echo("[3] Delete EAB Keys")
        click.echo("[4] Change Template Mapping")
        click.echo("[5] Claims")
        click.echo("[6] Identifiers")
        click.echo("[7] Manage System Settings")
        click.echo("[8] Exit")

        choice = click.prompt("Choose what action you want to execute (1-8)", default="", type=int)

        if choice == 1:
            get_sub()
        elif choice == 2:
            eab_keys()
        elif choice == 3:
            delete_eab_keys()
        elif choice == 4:
            change_template_mapping_menu()
        elif choice == 5:
            claims_menu()
        elif choice == 6:
            identifiers_menu()
        elif choice == 7:
            system_settings_menu()
        elif choice == 8:
            click.secho("Exiting", fg="cyan")
            sys.exit(0)
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 8.", fg="red")
            sub_menu()


def account():
    while True:
        click.clear()
        click.secho("=== Account Admin ===", fg="cyan")
        click.echo("[1] Get claim Subject")
        click.echo("[2] Get EAB Keys")
        click.echo("[3] Delete EAB Keys")
        click.echo("[4] Change Template Mapping")
        click.echo("[5] Exit")

        choice = click.prompt("Choose what action you want to execute (1-5)", default="", type=int)

        if choice == 1:
            get_sub()
        elif choice == 2:
            eab_keys()
        elif choice == 3:
            delete_eab_keys()
        elif choice == 4:
            change_template_mapping_menu()
        elif choice == 5:
            click.secho("Exiting", fg="cyan")
            sys.exit(0)
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

        choice = click.prompt("Choose what action you want to execute (1-3)", default="", type=int)

        if choice == 1:
            eab_keys(variables.get("client_id"),variables.get("client_secret"))  # done
        elif choice == 2:
            get_sub(variables.get("client_id"),variables.get("client_secret"))
        elif choice == 3:
            click.secho("Exiting", fg="cyan")
            sys.exit(0)
        else:
            click.secho("Invalid choice. Please enter a number between 1 and 4.", fg="red")
            click.pause()


def determine_access_level():
    try:
        claims_resp = acme_client.claim_get()
        claims = claims_resp.json()
        if claims:
            click.secho("You have Super Admin access.", fg="green")
            variables['user_type'] = 'admin'
            sleep(3)
            clear_screen()
            admin()
            return
    except Exception:
        pass

    try:
        accounts_resp = acme_client.admin_accounts_get()
        accounts = accounts_resp.json()
        if accounts:
            click.secho("You have Account Admin access.", fg="green")
            variables['user_type'] = 'account'
            sleep(3)
            clear_screen()
            account()
            return
    except Exception:
        pass

    click.secho("You have Enrollment User access .", fg="green")
    variables['user_type'] = 'user'
    sleep(3)
    clear_screen()
    user()

def sub_menu():
    """Present the Main Menu and handle user choices."""
    user_type = variables.get("user_type")
    if user_type is None:
        determine_access_level()
    elif user_type == 'admin':
        admin()
    elif user_type == 'account':
        account()
    elif user_type == 'user':
        user()


@click.command()
@click.option("--base-path", default=".", show_default=True,
              type=click.Path(exists=True, file_okay=False, path_type=str))
def main_menu(base_path: str) -> None:
    # load global variable
    global variables
    global acme_client


    try:
        variables = load_user_variables(base_path=base_path)
    except Exception as exc:
        click.secho(f"Failed to load configuration: {exc}", fg="red")
        raise SystemExit(1)

    # validate Required Variables
    required_keys = ["scope", "audience", "oidc_discovery_url", "acme_dns", "keyfactor_dns", "cert_check"]
    missing_keys = [key for key in required_keys if variables.get(key) in (None, "")]
    if missing_keys:
        raise ValueError(f"Missing required config keys in variables.py: {', '.join(missing_keys)}")

    client_id = variables.get("client_id")
    if not client_id:
        client_id = click.prompt("Enter OIDC Client ID", type=str).strip()
        if not client_id:
            click.secho("Client ID is required", fg="red")
            raise SystemExit(1)
        variables["client_id"] = client_id

    client_secret = variables.get("client_secret")
    if not client_secret:
        client_secret = click.prompt("Enter OIDC Client Secret", type=str, hide_input=True).strip()
        if not client_secret:
            click.secho("Client Secret is required", fg="red")
            raise SystemExit(1)
        variables["client_secret"] = client_secret

    try:
        get_oidc_json(variables["oidc_discovery_url"])
    except Exception as exc:
        click.secho(f"Failed to load OIDC metadata: {exc}", fg="red")
        raise SystemExit(1)

    acme_client = AcmeClient(variables)

    click.echo("Validating Access Token...")
    sleep(1)
    headers = create_auth_headers(variables["client_id"], variables["client_secret"])
    if not headers:
        click.echo("Failed to create Authorization Token")
        raise SystemExit(1)
    else:
        click.secho("Access Token is valid", fg="green")

    click.echo("Determining ACME role level")
    sleep(1)
    determine_access_level()


if __name__ == "__main__":
    main_menu()
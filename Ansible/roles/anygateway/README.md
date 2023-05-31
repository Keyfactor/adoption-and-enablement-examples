# Ansible Role: Keyfactor AnyGateway

### Purpose

The purpose of this Role is to Install and Configure AnyGateway to allow for inventory, revocation, or issuance of a Public Certificate Authority.

### Approach

The AnyGateway framework exposes a generic interface that enables Keyfactor Command to interact with an external CA as if it were a Microsoft CA.  The interface provides methods to allow a developer to execute certificate actions on behalf of Keyfactor. Actions include:

*	Enrollment
*	Revocation
*	Synchronization

### Enrollment

Through the enrollment function, Keyfactor can generate a CSR for a new, renewed, or reissued certificate and forward to the AnyGateway.  The gateway will translate this request into the required format for the external CA and call the appropriate endpoint.  Once issued, the AnyGateway will download the issued certificate and return it to Keyfactor.  

### Revocation

For revocation, the AnyGateway will translate standard Keyfactor revocation reasons to the CA and issue a request for revocation based on Certificate Identifier. 

### Synchronization

On a configured schedule, Keyfactor will initiate a full or incremental sync of certificates in the CA. This job will query the CA for certificates (based on OpenXPKI Realm) to determine if certificates have been added or modified.  These changes are reported to Keyfactor to ensure the latest information is available for reporting and automation.


Interested in Learning More? Check out [Keyfactor's Website](https://www.keyfactor.com/)

***
### Support for Ansible Role: Keyfactor AnyGateway

Ansible Role: Keyfactor AnyGateway is open source and there is **no SLA** for this tool/library/client. Keyfactor will address issues as resources become available. Keyfactor customers may request escalation by opening up a support ticket through their Keyfactor representative.

###### To report a problem or suggest a new feature, use the **[Issues](https://github.com/Keyfactor/adoption-and-enablement-examples/issues)** tab. If you want to contribute actual bug fixes or proposed enhancements, use the **[Pull requests](https://github.com/Keyfactor/adoption-and-enablement-examples/pulls)** tab.
___
### Requirements

* See "Preparing for the Keyfactor AnyGateway Server" documentation for Prerequisite details
* See Keyfactor GitHub Repositories for integration
* Minimum OS Version Requirement: Windows Server 2019
* Minimum Microsoft .NET Framework version 4.6.2
* Add AnyGateway MSI to the "files" directory
* Add Gateway DLL to the "files" directory 
* Add the Public CA Trust Certificates to the "files" directory
* configure the .json file
* update the variables in the defaults\main.yaml file

### Testing

This library has been tested against the following platform's: 
- Windows 2019 Server

#### Example Playbook

```
---yaml
# site.yml
- hosts: public_ca_gateway
  tasks:
    - import_role:
        name: gateway
```

#### Running the Playbook

```
ansible-playbook -i <inventory> site.yml
```

#### Tags

- `install`: Install the MSI & Configure the gateway using the powershell script
- `uninstall`: Uninstall the Anygateway

### Configurations
- Action Variables:
	- `new_install`: Used when a new installation with database creation - boolean Value (true or false)
    - `upgrade`: Used when only an upgrade is required - boolean Value (true or false)
    - `update_json`: Used when only a json update is required - boolean Value (true or false)
    - `uninstall`: Used when a software uninstall is required - boolean Value (true or false)
- Anygateway Variables:
	- `command_url`: URL of the Keyfactor Command Server
	- `keyfactorUser`: Keyfactor Command user with PkiManagement: Modify permissions
	- `keyfactorPassword`: Keyfactor Command user password
	- `anygateway_zip`: name of the downloaded software zip file
	- `anygateway_dir`: name of the unzipped directory from the `anygateway_zip`
	- `anygateway_msi_file_name`: name of the unzipped MSI file found in the `anygateway_dir`
    - `sql_fqdn`: FQDN of the SQL Server
    - `database_name`: Name of the database that will be created
    - `db_user`: Local SQL username 
    - `db_password`: Local SQL username password
    - `db_service_user`: username the service will runas
    - `cahostname`: fqdn of the server that will host the software
    - `logicalname`: name of the Certificate Authority
    - `rootforest`: Name of the root forest the CA will be aligned with
    - `ca_proxy_config_line`: Configuration line from the specific Public CA GitHub found in the keyfactor GitHub
    - `root_cert`: name of the Public CA root certificate file
    - `int_cert`: name of the Public CA intermediate certificate file
    - `default_install_dir`: default installation directory as found in the keyfactor GitHub
    - `gw_dll`: dll file found in the keyfactor GitHub release for the public CA - typically named <company>CAProxy.dll
- Do Not Change Variables
    - `install_source_dir`: this is the directory that will be created to store all the installation files - this will be removed when completed
    - `min_dotnet_version`: Min MS .Net Version required
    - `os_min_version`: Min MS OS Version required
    - `json_file_name`: name used for the configured json file
    - `temp_json`: name used for the temporary json file
### License
 Apache
### Author Information

&copy; [Keyfactor](https://www.keyfactor.com)

***

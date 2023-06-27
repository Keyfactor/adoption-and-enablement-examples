# Ansible Role: Keyfactor Universal Orchestrator&trade;

This role installs Keyfactor Universal Orchestrator on your target host. The purpose of this library is to automate the deployment of Keyfactor Orchestrator on to a remote host.

Remotely manage certificate stores across all IIS servers, F5 and Netscaler devices, FTP-capable devices, and Amazon Web Services (AWS) resources by deploying the agentless Keyfactor Universal Orchestrator. The Keyfactor Windows Orchestrator uses discovery to locate all certificates and imports them into Keyfactor Command allowing for a centrally managed platform for continuous monitoring, auditing, and maintenance of certificate lifecycles.

Interested in Learning More? Check out [Keyfactors Website](https://www.keyfactor.com/)

***

## Features

- Automation of the Installation and Configuration of Keyfactor Universal Orchestrator on a Windows Server.

- Idempotent design to reduce the impact of persistent testing in environments with rigorous testing requirements.

- Compatibility design allows for employment across different Infrastructures and Environments with minimal changes outside of the host file.

Note: This role is still in active development.  There may be unidentified issues and the roles variables may change as development continues.

## Technologies

* [Windows Server 2019](https://www.microsoft.com/en-us/windows-server) - Minimum Version Requirement for Target Host OS.
* [Ansible AWX 22.2.0](https://github.com/ansible/awx/releases) - Latest Version used.
* [Keyfactor Command 10.2.1.0](https://software.keyfactor.com/Guides/InstallingAgents/InstallingKeyfactorOrchestrators.pdf) - Latest Version used.

## Requirements

* See Keyfactor Orchestrator Installation and Configuration Guide for Orchestrator Prerequisite details
* Windows Server 2019 (Minimum Version Requirement)
* Ansible AWX 22.2.0 (Tested with 22.2.0)
* Add Orchestrator MSI zip file and Capabilities zip file to a directory called "files"
* update variables.

## Example Playbook

```
# playbook.yml
- hosts: orchestrator
  tasks:
    - import_role:
        name: Windows_Universal_Orchestrator
```

***

## Running the playbook

```
ansible-playbook -i <inventory> playbook.yml
```

## Tags

- `requirements` - Validates Server and Software Requirements.
- `copy` - Copies specified files to Target Host.
- `install` - Runs existing installation with configuration file generated.
- `cleanup` - removes install directory and files.
- `validation` - Validate the Orchestrator is listed in Keyfactor Command.

## Configurations

Here are the definitions for the variables within the `Defaults` > `main.yml` file. User's may need to adjust some configurations specific to their target install environment.

- `command_url`: `https://keyfactorurl.com` URL of the Keyfactor Command Instance.

- `keyfactorPassword`: `<Password>` Password used to connect Keyfactor Command.

- `keyfactorUser`: `<domain\\user>` active directory account used to connect Keyfactor Command.

- `orchestrator_name`: `<name of Orchestrator>` The name that will be known in Keyfactor Command.  This can be passed as a variable in the playbook.

- `orchestrator_zip`: `KeyfactorUniversalOrchestrator-10.2.0.zip` Name of the zipped installation files.  this is expected in the files' directory.

- `install_capabilities`: `true` used to tell the script to install capabilities in the "capabilities" file.

- `capabilities_file`: `capabilites.zip` Name of the zipfile with all the capabilities.

- `orchestrator_dir`: `Keyfactor Orchestrator\` Default directory name of where the Orchestrator will be installed. DO NOT CHANGE.

- `orchestrator_zip_name`: `<password>` Name of the zip file once it is moved locally to the host. DO NOT CHANGE.

- `orchestrator_Install_dir_name`: `KeyfactorUniversalOrchestrator` Name of the unzipped directory on the local host. DO NOT CHANGE.

- `install_target_dir`: `C:\Program Files\Keyfactor\` Default directory name of where keyfactor installs its products. DO NOT CHANGE.

- `install_source_dir`: `C:\InstallSource\` Directory where all install files will be moved.  This directory will be removed after the installation. DO NOT CHANGE.

- `powershell_template`: `generate-install-config.ps1` The name of the powershell script template installs the Orchestrator. DO NOT CHANGE.

- `powershell_file_name`: `install-config.ps1` The name of the generated powershell script to install the Orchestrator. DO NOT CHANGE.

- `os_min_version`: `10.0.17763` Requirement for Universal Orchestrator and can change as newer versions of the Orchestrator are released. DO NOT CHANGE.

- `min_dotnet_version`: `3.1.29` Requirement for Universal Orchestrator and can change as newer versions of the Orchestrator are released. DO NOT CHANGE.

- `orchestrator_service: 'KeyfactorOrchestrator-Default` Name of the Orchestrator Service. DO NOT CHANGE

## Installing Orchestrator Capabilites 
To add additional capabilities to the orchestrator, complete the following steps.
- Download the capability releases you desire from https://github.com/Keyfactor
- unzip all the files
- create a new directory called "capabilities"
- create a sub-folder for each capability (some capability folder names are outlined as requirements in the GitHub Repository)
- place the files from the unzipped capability in the new sub-folder for each capability.
- zip the capabilities directory with the same name
- move the capabilities zip file in the "file" directory of the playbook role.
- set the "install_capabilities" variable to "true"
- NOTE be sure to create the "Certificate StoreType" before running this playbook with capabilities.
***

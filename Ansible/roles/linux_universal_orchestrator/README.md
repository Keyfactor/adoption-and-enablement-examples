# Ansible Role: Keyfactor Universal Orchestrator&trade;

This role installs Keyfactor Universal Orchestrator on your target host. The purpose of this library is to automate the deployment of Keyfactor Orchestrator on to a remote host.

Remotely manage certificate stores across all IIS servers, F5 and Netscaler devices, FTP-capable devices, and Amazon Web Services (AWS) resources by deploying the agentless Keyfactor Universal Orchestrator. The Keyfactor Windows Orchestrator uses discovery to locate all certificates and imports them into Keyfactor Command allowing for a centrally managed platform for continuous monitoring, auditing, and maintenance of certificate lifecycles.

Interested in Learning More? Check out [Keyfactors Website](https://www.keyfactor.com/)

***

## Features

- Automation of the Installation and Configuration of Keyfactor Universal Orchestrator on a Linux Server.

- Idempotent design to reduce the impact of persistent testing in environments with rigorous testing requirements.

- Compatibility design allows for employment across different Infrastructures and Environments with minimal changes outside of the host file.

Note: This role is still in active development.  There may be unidentified issues and the roles variables may change as development continues.

## Technologies

* [Windows Server 2019](https://www.microsoft.com/en-us/windows-server) - Minimum Version Requirement for Target Host OS.
* [Ansible AWX 22.2.0](https://github.com/ansible/awx/releases) - Latest Version used.
* [Keyfactor Command 10.2.1.0](https://software.keyfactor.com/Guides/InstallingAgents/InstallingKeyfactorOrchestrators.pdf) - Latest Version used.

## Requirements

* See Keyfactor Orchestrator Installation and Configuration Guide for Orchestrator Prerequisite details
* Debian 16 or higher
* Redhat 7 or higher
* Ansible AWX 22.2.0 (Tested with 22.2.0)
* Add Orchestrator zip and update variables.

## Example Playbook

```
# playbook.yml
- hosts: orchestrator
  tasks:
    - import_role:
        name: linux_universal_orchestrator
```

***

## Running the playbook

```
ansible-playbook -i <inventory> playbook.yml
```

## Tags

- `requirments` - Validates Server and Software Requirements.
- `copy` - Copies specified files to Target Host.
- `install` - Runs existing installation with configuration file generated.
- `cleanup` - removes install directory and files.
- `validation` - Validate the Orchestrator is listed in Keyfactor Command.

## Configurations

Here are the definitions for the variables within the `Defaults` > `main.yml` file. User's may need to adjust some configurations specific to their target install environment.

- `install_source_dir`: `/var/tmp/KeyfactorUniversalOrchestrator` Directory where all install files will be moved.  This directory will be removed after the install. DO NOT CHANGE.

***

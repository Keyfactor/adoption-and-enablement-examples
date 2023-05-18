# **Document Version Control**

| **_Date_** | **_Author_** | **_Comments_** |
|--|--|--|
| 9/29/2022 | Jeremy Howland | Added Removal and Schedule Capabilities |
| 10/7/2022 | Adam Joyner | Convert to public facing document | 
| 5/2/2023 | Adam Joyner | Update to support IISU store type |


# **Supported Versions**

Keyfactor Command 9.X 

Keyfactor Command 10.X

# **Overview**
This automation package is configured so that after running the provided python script, the IIS Personal, IIS Revoked, IIS Roots, and IISU Certificate stores will be created and optionally scheduled.

# **Optional Use Case**
This Python script can be put into a Python Scheduler and ran to keep Windows Server Certificate Stores up-to-date with Keyfactor.

# **Requirements**

* At least one configured Universal Orchestrator

* The IISU Certificate Store type must be created prior to running the script.

* There are two options with this automation package: 

   * A [CSV can be created](mapping.csv) that contains the endpoint, orchestrator name and credentials to connect. This mean endpoints can be granularly mapped to orchestrators as desired. 
   * The automation script can scan Active Directory for any Windows endpoints and automatically assign endpoints to orchestrators. This method is available to customers' infrastructure which meet the following criteria: 
     *   All orchestrators must have network capability on the required Keyfactor ports to all discovered Windows Server endpoints.
     *   All endpoints have share a common local administrator service account.
     *   The provided script must have read access to the customers' entire Active Directory.
     *   Windows Server AD objects must have their operating system in the operatingSystem attribute, and the value must contain the string `server`
* Ensure that the IISU certificate store type has been created in the Keyfactor Instance
* Ensure the Containers for each IIS Certificate Store Type is created

# **Scripts**
 * [add_iis_v9.py](add_iis_v9.py) : Keyfactor Command v9 script
 * [add_iis_v10.py](add_iis_v10.py) : Keyfactor Command v10 script
 * [config.py](config.py) : Required configuration file
 * [mapping.csv](mapping.csv) : Sample CSV Import file

# **Deployment & Configuration Playbook**

1.  Copy the scripts to a host that has Python 3+ installed. Ensure that the `add_iis` script and `config.py` are in the same directory
2.  Ensure that `ldap3` has been installed from pip
    ```
    pip3 install ldap3
    ``` 
3. Modify `config.py` with the details corresponding to your Keyfactor instance information
4. Run the provided `add_iis` script. 
#### **CSV Import:**
This can be run from any host that can access the Keyfactor server
```
python3 add_iis.py -e <environment> -s <schedule(true/false)> -f /path/to/mapping.csv
```

#### **Domain Scan Import:**
This can be run from any host that can access the Keyfactor server. This also must be run in an environment that has access to the specified domain
```
python3 add_iis.py -e <environment> -s <schedule(true/false)> -i my -u domain\username -p password -dc DC.command.local
```
The `-u` and `-p` correspond to the common account that must have localadmin privileges on each of the client machine endpoints whose certificate stores are being inventoried.

The `-dc` flag must correspond to an entry in the `LDAP_CONTROLLERS` dictionary in `config.py`. The entry can either map to a DNS name or and IP address if local DNS lookups are unavailable.

The `-s` flag correspond to a boolean true or false statement if you choose to have a set schedule for all your certificate stores.

If the `-s` is set to "true", the following flags are also required: 
* `-r` corresponds to a run_time variable which is the time you want the schedule to run.  It is required in this format: HH:MM:SS.
* `-fr` corresponds to a frequency variable which is the frequency the schedule will run.  the  options are: (case-sensitive) exactlyOnce, monthly, weekly, daily.
* `-d` corresponds to a day variable which is the day you want the job to run.  The options are: Mon, Tue, Wed, Thu, Fri, Sat, Sun

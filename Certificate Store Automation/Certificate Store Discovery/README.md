# **Document Version Control**

| **_Date_** | **_Author_** | **_Comments_** |
|--|--|--|
| 9/23/2022 | Jeremy Howland | Create Initial Draft |
| 10/7/2022 | Adam Joyner | Convert to public facing document | 


# **Supported Versions**

Keyfactor Command 9.X 

Keyfactor Command 10.X

# **Overview**
This automation package is configured so that after running the provided python script, and using the Windows or Linux switch, the JKS-SSH, PEM-SSH discovery jobs will be scheduled or using the F5 switch, the F5 CA Bundle and F5 SSL Profile discovery jobs will be scheduled.

# **Requirements**

* At least one configured Universal Orchestrator

* The F5 Certificate Store type must be created prior to running the script.

* There are seven  to pass into the script: 

   * Environment 
     * name of the environment that will determine variables in the config.py that is imported.
   * orchestrator_name
     * Bane if the Orchestrator that will complete Discovery Job and be assigned to the certificate stores that are discovered. 
   * discovery_type
     * specify if the Server_node is windows, linux, or f5.
   * server_node
     * fully qualified domain name of the server or f5 node.
   * run_every_time
     * Time the job should run on the specified day (format = HH:MM:SS).
   * effective_date
     * effective date of the discovery job is used to find the next dayofweek date.
   * dayofweek
     * day of week this job should run on.  values are: mon, tue, wed, thu, fri, sat, sun.

# **Scripts**
 * [discovery_v9.py](discovery_v9.py) : Keyfactor Command v9 Script
 * * [discovery_v10.py](discovery_v10.py) : Keyfactor Command v10 Script
 * [config.py](config.py) : Required configuration file

# **Deployment & Configuration Playbook**

1. Copy the scripts to a host that has Python 3+ installed. Ensure that the `discovery` script and `config.py` are in the same directory
2. Modify `config.py` with the details corresponding to your Keyfactor instance information
3. Run the provided `discovery` script. 

#### **Discovery job creation:**
This can be run from any host that can access the Keyfactor server.
```
python3 discovery.py -e '<enviroment>' -o '<orchestrator_name>' -t '<discovery_type>' -s '<server_node>' -r '<run_every_time>' -ef '<effective_date>' -d '<dayofweek>'
```

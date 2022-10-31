from config import *
from ldap3 import Server, Connection, ALL, NTLM, Tls, ALL_ATTRIBUTES
import requests
import os
import sys
import json
import random
import csv
import re
import ssl
import argparse
import calendar
from datetime import timedelta, datetime
from pytz import timezone


def ok_codes(result):
    if result.status_code >= 400:
        print(f'Error Code: {result.status_code}')
        print(f"Output: {result.content.decode('utf-8')}")
        return False
    else:
        return True


def get_keyfactor_iis_stores(env):
    results = []
    url = 'KeyfactorAPI/CertificateStores?certificateStoreQuery.queryString=StorePath%20-contains%20%22IIS%22%20OR' \
          '%20StorePath%20-contains%20%22MY%22%20OR%20StorePath%20-contains%20%22WebHosting%22&certificateStoreQuery' \
          '.returnLimit='
    urlpage = 'KeyfactorAPI/CertificateStores?certificateStoreQuery.queryString=StorePath%20-contains%20%22IIS%22' \
              '%20OR%20StorePath%20-contains%20%22MY%22%20OR%20StorePath%20-contains%20%22WebHosting%22' \
              '&&certificateStoreQuery.pageReturned='
    urlpath = f'{url}1'
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=False)
    returned_headers = f.headers
    try:
        total_number = int(returned_headers["x-total-count"])
        print(f'getting a total of: {total_number}')
    except:
        print(f'ERROR: Could not pull total number from {f.headers}. {f.url}')
        sys.exit(16)
    pages = total_number // 50 + 1
    for page in range(1, pages + 1):
        urlpath2 = f'{urlpage}{page}'
        fullurl = f'{KEYFACTOR_URLS[env]}{urlpath2}'
        f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                         verify=False)
        if not ok_codes(f):
            print("ERROR: data information call failed.")
            sys.exit(12)
        data = json.loads(f.content)
        for d in data:
            new_data = d['ClientMachine']
            results.append(new_data)
    return results


def get_one_uo(env, agentname):
    urlPath = f'KeyfactorApi/Agents?pq.queryString=clientmachine%20-eq%20%22{agentname}%22%20AND%20status%20-eq%202'
    fullURL = f'{KEYFACTOR_URLS[env]}{urlPath}'
    f = requests.get(fullURL, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    if not ok_codes(f):
        print(
            f'ERROR: Received {f.status_code} on POST to create IIS Store for {agentname}. Results: {f.content} URL: ({f.url})')
        sys.exit(16)
    results = json.loads(f.content.decode('utf-8'))
    return results


def get_uo(env):
    urlPath = 'KeyfactorApi/Agents?pq.queryString=Capabilities%20-contains%20%22IIS%22%20AND%20Status%20-eq%20%222%22&pq.returnLimit=1000'
    fullURL = f'{KEYFACTOR_URLS[env]}{urlPath}'
    f = requests.get(fullURL, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    if not ok_codes(f):
        print(f'ERROR: Received {f.status_code} Results: {f.content} URL: ({f.url})')
        sys.exit(16)
    results = json.loads(f.content.decode('utf-8'))
    return results


'''
Gets a list of client names from a given domain. The domain parameter expects a key of 
the LDAP_CONTROLLER dictionary.
'''


def get_client_names(domain):
    servers = []
    uid = LDAP_CONTROLLER[domain]["username"]
    password = LDAP_CONTROLLER[domain]["password"]
    # tls_configuration = Tls(validate=ssl.CERT_NONE, version=ssl.PROTOCOL_TLSv1)
    # d_server = Server(domain, use_ssl=True, get_info=ALL, tls=tls_configuration)
    d_server = Server(domain, get_info=ALL)
    searchstring = LDAP_CONTROLLER[domain]["query"]
    with Connection(d_server, user=uid, password=password, authentication=NTLM) as conn:
        conn.search(searchstring, '(&(objectclass=Computer)(operatingSystem=*server*)(CN=*))',
                    attributes=ALL_ATTRIBUTES)
        for entry in conn.entries:
            cn = entry.cn.value
            try:
                fqdn = entry.dnshostname.value
                servers.append(fqdn)
            except:
                print(f'ERROR: Warning! DNSHOSTNAME not found in entry: {cn}')
                continue
    return servers


def check_keyfactor_iis_stores(env, clientmachine):
    urlpath = f'KeyfactorAPI/CertificateStores?certificateStoreQuery.queryString=ClientMachine%20-eq%20%22{clientmachine}' \
              f'%22%20AND%20(StorePath%20-contains%20%22IIS%22%20OR%20StorePath%20-contains%20%22My%22' \
              f'%20OR%20StorePath%20-contains%20%22Web%22)&certificateStoreQuery.returnLimit=1 '
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    if not ok_codes(f):
        print(f'ERROR: Received a {f.status_code} attempting a post on {f.url} received message {f.content}')
        sys.exit(16)
    else:
        results = json.loads(f.content.decode('utf-8'))
        print(f'Info: Getting all IIS store type for {clientmachine}')
    return results


def pull_certstore_types(env, name):
    urlpath = f'KeyfactorAPI/CertificateStoreTypes/Name/{name}'
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    results = json.loads(f.content.decode('utf-8'))
    return results


def check_container(env, ctype):
    name = ctype['Name']
    storetype = ctype['StoreType']
    urlpath = f"KeyfactorApi/CertificateStoreContainers?pq.queryString=CertStoreType%20-eq%20%22{storetype}%22"
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    if not ok_codes(f):
        print(f'ERROR: Received a {f.status_code} attempting a get on {f.url} received message {f.content}')
        sys.exit(16)
    else:
        results = json.loads(f.content.decode('utf-8'))
    if len(results) != 0:
        return results[0]['Id']
    else:
        print(f'{name} Container is not defined and Certificate Store will not be assigned to a Container')
        return 'null'


def check_certstore_server(env, clientmachine, user, password, ctype_info):
    serverregistration = ctype_info['ServerRegistration']
    urlpath = f"KeyfactorApi/CertificateStores/Server?pq.queryString=Name%20-eq%20%22{clientmachine}%22%20AND%20ServerType%20-eq%20{serverregistration}"
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    if not ok_codes(f):
        print(f'ERROR: Received a {f.status_code} attempting a post on {f.url} received message {f.content}')
        sys.exit(16)
    else:
        results = json.loads(f.content.decode('utf-8'))
    if len(results) != 0:
        return results
    else:
        create_cert_store(env, clientmachine, ctype_info, user, password)


def create_cert_store(env, clientmachine, ctype_info, user, password):
    urlpath = f"KeyfactorApi/CertificateStores/Server"
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    define_body: dict = {
        "UseSSL": False,
        "ServerType": ctype_info['ServerRegistration'],
        "Name": clientmachine,
        'Username': {'SecretValue': user},
        'Password': {'SecretValue': password}
    }
    define_body = json.dumps(define_body)
    f = requests.post(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), data=define_body, proxies=PROXY,
                      headers=HEADERS, verify=True)
    if not ok_codes(f):
        print(f'ERROR: Received a {f.status_code} attempting a post on {f.url} received message {f.content}')
        sys.exit(16)
    else:
        results = json.loads(f.content.decode('utf-8'))
        print(f'Info: Certificate Store Server for: {clientmachine} was created')
    return results


def schedule_time(iteration, run_time, day_of_week):
    effective_date = datetime.today().strftime('%Y-%m-%d')
    date_time = effective_date + " " + run_time
    date_time = datetime.strptime(f"{date_time}", "%Y-%m-%d %H:%M:%S")
    days = list(calendar.day_abbr)
    start_time_w = date_time.isoweekday()
    target_w = days.index(day_of_week)
    if start_time_w < target_w:
        day_diff = target_w - start_time_w
    else:
        day_diff = 1 - (start_time_w - target_w)
    results = date_time + timedelta(days=day_diff)
    schdate = results.strftime('%Y-%m-%d')
    fmt = '%Y-%m-%d %H:%M:%S'
    runTime = f'{schdate} {run_time}'
    date_time_obj = datetime.strptime(runTime, fmt)
    est_date_time_obj = timezone(CURRENT_TZ).localize(date_time_obj)
    utc_time = est_date_time_obj.astimezone(timezone('UTC'))
    newdate, newtime = utc_time.strftime(fmt).split()
    exectime = f'{newdate}T{newtime}.000Z'
    day = list(calendar.day_abbr)
    days = day.index(day_of_week)
    if iteration == 'daily':
        inventory_schedule = {'Daily': {'Time': exectime}, },
    elif iteration == 'weekly':
        inventory_schedule = {"Weekly": {"Days": [days], "Time": exectime, }},
    elif iteration == 'monthly':
        inventory_schedule = {"Monthly": {"Day": days, "Time": exectime}, },
    elif iteration == 'exactlyOnce':
        inventory_schedule = {"ExactlyOnce": {"Time": exectime}}
    return inventory_schedule


def add_iis(env, iiswbinstorepath, orchestrator, clientmachine, ctype, properties, schedule, iteration, run_time,
            day_of_week):
    agent = get_one_uo(env, orchestrator)
    if not agent:
        print(f'ERROR: Orchestrator not found with name: {orchestrator}')
        sys.exit(16)
    if len(ctype) < 2:
        storepath = iiswbinstorepath
        storetype = ctype[0]["StoreType"]
        ctype = ctype[0]
    else:
        storepath = ctype['StorePathValue']
        storetype = ctype["StoreType"]
    check_container_results = check_container(env, ctype)
    containerid = check_container_results
    urlpath = 'KeyFactorAPI/CertificateStores'
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    if schedule:
        sresults = schedule_time(iteration, run_time, day_of_week)
        body = json.dumps({
            "ContainerId": containerid,
            "ClientMachine": clientmachine,
            "AgentId": agent[0]["AgentId"],
            "Storepath": storepath,
            "CertStoreType": storetype,
            "CreateIfMissing": False,
            "Approved": True,
            "Properties": properties,
            "InventorySchedule": sresults[0]
        })
    else:
        body = json.dumps({
            "ContainerId": containerid,
            "ClientMachine": clientmachine,
            "AgentId": agent[0]["AgentId"],
            "Storepath": storepath,
            "CertStoreType": storetype,
            "CreateIfMissing": False,
            "Approved": True,
            "Properties": properties
        })
    f = requests.post(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), data=body, proxies=PROXY, headers=HEADERS,
                      verify=True)
    print(f'Adding certificate stores for {clientmachine}')
    if not ok_codes(f):
        print(
            f'ERROR: Received {f.status_code} on POST to create IIS Store for {clientmachine}. Results: {f.content} URL:({f.url})')
        print(f'ERROR: Body: {body}')
        sys.exit(16)
    results = json.loads(f.content.decode('utf-8'))
    Id = results['Id']
    if len(results['Id']) != 0:
        print(f'Info: Certificate Store for {clientmachine} was successfully created')
    return


def remove_stores(env, keyfactor_store):
    urlpath = f'/KeyfactorApi/CertificateStores?certificateStoreQuery.queryString=ClientMachine%20-startswith%20%22{keyfactor_store}%22&certificateStoreQuery.returnLimit=100 '
    fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
    f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=False)
    f = f.content.decode('utf-8')
    stores_data = json.loads(f)
    if len(stores_data) > 0:
        print(f'Certificate stores detected for {keyfactor_store}. Removing Stores.')
        guids = []
        for store in stores_data:
            guids.append(store['Id'])
        body = '["' + '", "'.join(guids) + '"]'
        stores_delete_response = requests.delete(f'{KEYFACTOR_URLS[env]}KeyfactorApi/CertificateStores', data=body,
                                                 auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), headers=HEADERS,
                                                 verify=False)
        stores_delete_response.content.decode('utf-8')
        print(f'INFO: This certificate store are not in Active directory and will be removed from Keyfactor: {keyfactor_store}')
    else:
        print(f'No certificate stores detected for {keyfactor_store}')


def work(env, clientmachine, iiswbinstorepath, username, password, schedule, iteration, run_time, day_of_week,
         orchestrator=None):
    ctypenames = ['IIS', "IISwbin"]
    for name in ctypenames:
        ctype_info = pull_certstore_types(env, name)
        if orchestrator is None:
            orchestrators = get_uo(env)
            orchestrator = random.choice(orchestrators)
            orchestrator = orchestrator['ClientMachine']
        for ctype in ctype_info:
            shortname = ctype['ShortName']
            if shortname == 'IISWBin':
                check_certstore_server(env, clientmachine, username, password, ctype)
                properties = "{\"spnwithport\":{\"value\":\"false\"},\"WinRm Port\":{\"value\":\"5985\"},\"WinRm Protocol\":{\"value\":\"http\"}}"
                add_iis(env, iiswbinstorepath, orchestrator, clientmachine, ctype_info, properties, schedule, iteration, run_time, day_of_week)
            else:
                properties = '{"UseSSL": {"value":"false"}}'
                add_iis(env, iiswbinstorepath, orchestrator, clientmachine, ctype, properties, schedule, iteration, run_time, day_of_week)


def main():
    parser = argparse.ArgumentParser()
    # Required Argument
    requirednamed = parser.add_argument_group('required arguments')
    requirednamed.add_argument("-e", "--environment", help="Environment Name", required=True)
    requirednamed.add_argument("-s", "--schedule", help="defines if a schedule will be used", required=True)

    # One is required
    mutually_exclusive_group = parser.add_mutually_exclusive_group(required=True)
    mutually_exclusive_group.add_argument("-f", "--file", help="Path to CSV import file")
    mutually_exclusive_group.add_argument("-dc", "--domaincontroller",
                                          help="Domain controller specified in the config file")

    # Optional Arguments for Scanning AD
    parser.add_argument("-i", "--iiswbinstorepath", help="IIS w/ Bindings store path")
    parser.add_argument("-u", "--username", help="Localadmin Username on client machine")
    parser.add_argument("-p", "--password", help="Localadmin Password on client machine")
    parser.add_argument("-r", "--run_time", help="time the job is effective by value must be in format (HH:MM:SS)")
    parser.add_argument("-fr", "--frequency",
                        help=", how often you want to inventory job to run, options are:(exactlyOnce, monthly, weekly, daily ")
    parser.add_argument("-d", "--day_of_week",
                        help="(used for weekly and monthly frequency) day you wish to have the job run on a frequency, values are (Mon, Tue, Wed, Thu, Fri, Sat, Sun)")
    args = parser.parse_args()

    env = args.environment
    file = args.file
    iteration = args.frequency
    run_time = args.run_time
    day_of_week = args.day_of_week
    schedule = args.schedule

    print('starting add_iis job')
    if file is not None:
        with open(file, mode='r') as csv_file:
            csv_reader = csv.reader(csv_file)
            line_count = 0
            for row in csv_reader:
                if line_count == 0:
                    line_count += 1
                else:
                    if row[0]:
                        orchestrator = row[0]
                    else:
                        orchestrator = None
                    clientmachine = row[1]
                    iiswbinstorepath = row[2]
                    username = row[3]
                    password = row[4]
                    line_count += 1
                    validation = check_keyfactor_iis_stores(env, clientmachine)
                    if len(validation) > 2:
                        print(f'certificate store for {clientmachine}exists already, moving on...')
                    else:
                        work(env, clientmachine, iiswbinstorepath, username, password, schedule, iteration, run_time,
                             day_of_week, orchestrator)
    else:
        clientmachines = get_client_names(args.domaincontroller)
        keyfactor_stores = get_keyfactor_iis_stores(env)
        keyfactor_stores = list(dict.fromkeys(keyfactor_stores))
        iiswbinstorepath = args.iiswbinstorepath
        username = args.username
        password = args.password
        orchestrator = None
        for keyfactor_store in keyfactor_stores:
            if keyfactor_store not in clientmachines:
                remove_stores(env, keyfactor_store)
        for clientmachine in clientmachines:
            validation = check_keyfactor_iis_stores(env, clientmachine)
            if len(validation) > 0:
                print(f'A Certificate Store for {clientmachine} exists already, moving on...')
            else:
                work(env, clientmachine, iiswbinstorepath, username, password, schedule, iteration, run_time,
                     day_of_week, orchestrator)

    print('completed add_iis job')


if __name__ == "__main__":
    main()

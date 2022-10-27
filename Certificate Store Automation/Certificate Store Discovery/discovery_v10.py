from config import *
import argparse
import requests
import sys
import json
from datetime import timedelta
from datetime import datetime
from pytz import timezone


def ok_codes(result):
    if result.status_code >= 400:
        print(f'Error Code: {result.status_code}')
        print(f"Output: {result.content.decode('utf-8')}")
        return False
    else:
        return True


def get_one_uo(env, orchestrator_name):
    urlPath = f'KeyfactorApi/Agents?pq.queryString=clientmachine%20-eq%20%22{orchestrator_name}%22%20AND%20status%20-eq%202'
    fullURL = f'{KEYFACTOR_URLS[env]}{urlPath}'
    f = requests.get(fullURL, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                     verify=True)
    if not ok_codes(f):
        print(
            f'ERROR: Received {f.status_code} on POST to create IIS Store for {orchestrator_name}. Results: {f.content} URL: ({f.url})')
        sys.exit(16)
    results = json.loads(f.content.decode('utf-8'))
    return results


def store_types(env, discovery_type):
    if discovery_type == 'f5':
        stype = F5_LIST
    else:
        stype = OTHER_LIST
    all_stypes = []
    for storetype in stype:
        urlpath = f"KeyfactorApi/CertificateStoreTypes/Name/{storetype}"
        fullurl = f'{KEYFACTOR_URLS[env]}{urlpath}'
        f = requests.get(fullurl, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), proxies=PROXY, headers=HEADERS,
                         verify=True)
        if not ok_codes(f):
            print(f'Received {f.status_code} while attempting to reach {f.url} received message {f.content}')
            sys.exit(16)
        results = json.loads(f.content.decode('utf-8'))
        if storetype == 'JKS' or storetype == 'PEM':
            serverregistration = ''
        else:
            serverregistration = (results[0]['ServerRegistration'])
        store_type = (results[0]['StoreType'])
        name = results[0]['ShortName']
        result_dict = {'name': name, 'store_type': store_type, 'serverregistration': serverregistration}
        all_stypes.append(result_dict)
    return all_stypes


def schedule_time(run_every_time, effective_date, dayofweek):
    date_time = effective_date + " " + run_every_time
    date_time = datetime.strptime(f"{date_time}", "%Y-%m-%d %H:%M:%S")
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    start_time_w = date_time.isoweekday()
    target_w = days.index(dayofweek) + 1
    if start_time_w < target_w:
        day_diff = target_w - start_time_w
    else:
        day_diff = 7 - (start_time_w - target_w)
    results = date_time + timedelta(days=day_diff)
    schdate = results.strftime('%Y-%m-%d')
    fmt = '%Y-%m-%d %H:%M:%S'
    runTime = f'{schdate} {run_every_time}'
    date_time_obj = datetime.strptime(runTime, fmt)
    est_date_time_obj = timezone(CURRENT_TZ).localize(date_time_obj)
    utc_time = est_date_time_obj.astimezone(timezone('UTC'))
    newdate, newtime = utc_time.strftime(fmt).split()
    exectime = f'{newdate}T{newtime}.000Z'
    return exectime


def schedule_discovery(env, server_node, orchestrator_id, discovery_type, exectime, username, password):
    stypes = store_types(env, discovery_type)
    urlpath = 'KeyfactorAPI/CertificateStores/DiscoveryJob'
    url = f'{KEYFACTOR_URLS[env]}{urlpath}'
    for stype in stypes:
        if stype['name'] == 'JKS' or stype['name'] == 'PEM':
            continue
        name = stype['name']
        store_type = stype['store_type']
        if discovery_type == 'linux':
            body: dict = {
                'ClientMachine': server_node,
                'AgentId': orchestrator_id,
                'Dirs': '/',
                'Compatibility': 'true',
                'Symlinks': 'true',
                'Type': store_type,
                'Extensions': LINUX_EXTENSIONS[name],
                'IgnoredDirs': '',
                'NamePatterns': '',
                'ServerUsername': {"SecretValue": username},
                'ServerPassword': {"SecretValue": password},
                'ServerUseSsl': 'false',
                'KeyfactorSchedule': {"ExactlyOnce": {'Time': exectime}}
            }
        elif discovery_type == 'windows':
            client_machine = f'http://{server_node}:5985'
            body: dict = {
                'ClientMachine': client_machine,
                'AgentId': orchestrator_id,
                'Dirs': 'fullscan',
                'Compatibility': 'true',
                'Symlinks': 'true',
                'Type': store_type,
                'Extensions': WINDOWS_EXTENSIONS[name],
                'IgnoredDirs': '',
                'NamePatterns': '',
                'ServerUsername': {"SecretValue": username},
                'ServerPassword': {"SecretValue": password},
                'ServerUseSsl': 'false',
                'KeyfactorSchedule': {"ExactlyOnce": {'Time': exectime}}
            }
        elif discovery_type == 'f5':
            print(server_node)
            body: dict = {
                'ClientMachine': server_node,
                'AgentId': orchestrator_id,
                'Dirs': 'na',
                'Compatibility': 'false',
                'Symlinks': 'true',
                'Type': store_type,
                'Extensions': '',
                'IgnoredDirs': '',
                'NamePatterns': '',
                'ServerUsername': {"SecretValue": username},
                'ServerPassword': {"SecretValue": password},
                'ServerUseSsl': 'false',
                'KeyfactorSchedule': {"ExactlyOnce": {'Time': exectime}}
            }
        else:
            print(f'ERROR: Discovery Type: {discovery_type} is invalid.')
        # body['KeyfactorSchedule'] = exectime
        body = json.dumps(body)
        print(body)
        f = requests.put(url, auth=(KEYFACTOR_ID[env], KEYFACTOR_PASS[env]), data=body, proxies=PROXY, headers=HEADERS,
                         verify=True)
        if not ok_codes(f):
            print(f'Received an {f.status_code} while making a call to {f.url} received message {f.content}')
    print(f'Discovery scheduled for {server_node}')
    return


def main():
    parser = argparse.ArgumentParser(description='A Script to manage Keyfactor Discovery.')
    # # Required Argument
    parser.add_argument("-e", "--environment", help="Environment Name")
    parser.add_argument("-o", "--orchestrator_name", help="Name of the orchestrator with access to server")
    parser.add_argument("-t", "--discovery_type", help="Type of discovery, values include (windows, linux, f5")
    parser.add_argument("-s", "--server_node",
                        help="Fully Qualified Name of the server or node to run the certificate discovery on")
    parser.add_argument("-r", "--run_every_time",
                        help="time the job is effective by value must be in format (HH:MM:SS)")
    parser.add_argument("-ef", "--effective_date",
                        help="date the job is effective by value must be in format (YYYY-mm-dd)")
    parser.add_argument("-d", "--dayofweek",
                        help="day this discovery job will run, values are (mon, tue, wed, thu, fri, sat, sun)")
    parser.add_argument("-u", "--username", help="Localadmin Username on client machine")
    parser.add_argument("-p", "--password", help="Localadmin Password on client machine")
    args = parser.parse_args()
    env = args.environment
    orchestrator_name = args.orchestrator_name
    discovery_type = args.discovery_type
    server_node = args.server_node
    run_every_time = args.run_every_time
    effective_date = args.effective_date
    dayofweek = args.dayofweek
    username = args.username
    password = args.password
    exectime = schedule_time(run_every_time, effective_date, dayofweek)
    if orchestrator_name:
        orchestrator_info = get_one_uo(env, orchestrator_name)
        if orchestrator_info:
            orchestrator_id = orchestrator_info[0]['AgentId']
        else:
            print(f'ERROR: orchestrator_name error')
            sys.exit(16)
    else:
        print(f'ERROR: orchestrator_name is not defined')
        sys.exit(16)
    if discovery_type:
        print(f'scheduling Discovery for {server_node} at {exectime}')
        schedule_discovery(env, server_node, orchestrator_id, discovery_type, exectime, username, password)
    else:
        print(f'ERROR: discovery_type is not defined')
        sys.exit(16)


if __name__ == "__main__":
    main()

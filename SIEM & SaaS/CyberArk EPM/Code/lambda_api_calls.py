import boto3
import requests
import os
import json
import gzip
from datetime import datetime
from uuid import uuid4

s3_client = boto3.client('s3')
management_log = {'error': [], 'update_position_file': [], 'check_position_file': [], 'logshipper': []}


def lambda_handler(event, context):
    authorisation = cyberark_epm_auth()

    if validate_requests(response=authorisation.json(), check='auth'):
        apps = sets(authorisation.json()["ManagerURL"], authorisation.json()["EPMAuthenticationResult"])

        set_ids = []
        for i in range(apps.json()["SetsCount"]):
            set_ids.append(apps.json()["Sets"][i]["Id"])

        if os.environ["CHOICE_SETID"] in set_ids:
            index = set_ids.index(os.environ["CHOICE_SETID"])
            records = raw_events(authorisation.json()["ManagerURL"],
                                 apps.json()["Sets"][index]["Id"],
                                 authorisation.json()["EPMAuthenticationResult"])

            if validate_requests(response=records.json(), check='events', set_name=apps.json()["Sets"][index]["Name"]):
                events = log_collection_s3(records,
                                           apps.json()["Sets"][index]["Id"],
                                           apps.json()["Sets"][index]["Name"])
                logshipper(events)
        else:
            for i in range(len(apps.json()["Sets"])):
                records = raw_events(authorisation.json()["ManagerURL"],
                                     apps.json()["Sets"][i]["Id"],
                                     authorisation.json()["EPMAuthenticationResult"])

                if validate_requests(response=records.json(), check='events', set_name=apps.json()["Sets"][i]["Name"]):
                    events = log_collection_s3(records,
                                               apps.json()["Sets"][i]["Id"],
                                               apps.json()["Sets"][i]["Name"])
                    logshipper(events)

    print(management_log)


def cyberark_epm_auth():
    url = "https://{EPM_SERVER}/EPM/API/Auth/EPM/Logon".format(EPM_SERVER=os.environ["EPM_SERVER"])
    cred = {
        "Username": os.environ["USERNAME"],

        "Password": os.environ["PASSWORD"],

        "ApplicationID": os.environ["APPLICATIONID"]
    }

    auth = requests.post(url, json=cred)

    return auth


def sets(manager_url, epm_auth):
    url = f'{manager_url}/EPM/API/Sets'

    headers = {'Authorization': f'basic {epm_auth}'}

    apps = requests.get(url, headers=headers)

    return apps


def raw_events(manager_url, sets_id, epm_auth):
    timestamp, position_file_exists = check_position_file(sets_id)

    if timestamp is not None:
        url = f'{manager_url}/EPM/API/Sets/{sets_id}/Events/Search'

        headers = {'Authorization': f'basic {epm_auth}'}

        body = {
            "filter": "arrivalTime GE \"{arrival_time}\"".format(arrival_time=timestamp)
        }

        records = requests.post(url, headers=headers, json=body)

        return records
    else:
        url = f'{manager_url}/EPM/API/Sets/{sets_id}/Events/Search'

        headers = {'Authorization': f'basic {epm_auth}'}

        records = requests.post(url, headers=headers)

        return records


def log_collection_s3(records, sets_id, sets_name):
    logs = []

    for event in records.json()['events']:
        record = {
            'cyberark': {
                'sets_id': sets_id,
                'sets_name': sets_name,
                'timestamp': str(int((datetime.strptime(event['arrivalTime'], '%Y-%m-%dT%H:%M:%S.%fZ') - datetime(1970, 1, 1)).total_seconds() * 1000)),
                'event': event
            }
        }

        logs.append(record)

    dictionary = {
        'Records': logs
    }

    arrival_time = records.json()['events'][0]['arrivalTime']

    logs = json.dumps(dictionary).encode("utf-8")

    bucket = os.environ["BUCKETNAME"]
    upload_path = f'/tmp/records_{uuid4()}.json.gz'
    path = f'CyberkArk_EPM/Logs/{sets_id}/records_{uuid4()}.json.gz'

    with gzip.open(upload_path, "wb") as outfile:
        outfile.write(logs)

    s3_client.upload_file(upload_path, bucket, path)

    update_position_file(arrival_time, sets_id)

    return dictionary


def logshipper(events):
    sending = []

    logs = events['Records']

    for log in logs:
        cur_time = log['cyberark']['timestamp']
        sending.append({'severity': 3, 'text': log, 'timestamp': cur_time})

    endpoint = os.environ["CX_ENDPOINT"]
    object_to_send = {
        'privateKey': os.environ["CX_PRIVATE_KEY"],
        'applicationName': os.environ["CX_APP_NAME"],
        'subsystemName': os.environ["CX_SUB_NAME"],
        'logEntries': sending
    }

    response = requests.post(endpoint, headers={'User-Agent': 'Coralogix', 'Content-Type': 'application/json'},
                             json=object_to_send)

    management_log['logshipper'].append(response)


def check_position_file(sets_id):
    position_file_log = {'sets_id': sets_id}

    timestamp = None
    position_file_exists = False

    bucket = os.environ["BUCKETNAME"]
    download_path = '/tmp/position_file.json'
    path = f'CyberkArk_EPM/position_file.json'

    try:
        s3_client.download_file(bucket, path, download_path)

        with open(download_path) as data_file:
            file_data = json.load(data_file)
    except:
        position_file_log['timestamp'] = timestamp
        position_file_log['position_file_exists'] = position_file_exists

        return timestamp, position_file_exists

    positions = file_data['positions']

    for i in range(len(positions)):
        if positions[i]['sets_id'] == sets_id:
            timestamp = positions[i]['timestamp']
            break

    position_file_exists = True

    position_file_log['timestamp'] = timestamp
    position_file_log['position_file_exists'] = position_file_exists

    management_log['check_position_file'].append(position_file_log)

    return timestamp, position_file_exists


def update_position_file(arrival_time, sets_id):
    timestamp, position_file_exists = check_position_file(sets_id)

    bucket = os.environ["BUCKETNAME"]
    download_path = '/tmp/position_file.json'
    path = f'CyberkArk_EPM/position_file.json'

    if position_file_exists:
        s3_client.download_file(bucket, path, download_path)

        with open(download_path) as data_file:
            file_data = json.load(data_file)

        positions = file_data['positions']

        if timestamp is not None:
            for i in range(len(positions)):
                if positions[i]['sets_id'] == sets_id:
                    positions[i]['timestamp'] = arrival_time
                    break
        else:
            position = {
                'sets_id': sets_id,
                'timestamp': arrival_time
            }

            positions.append(position)

            file_data['positions'] = positions
    else:
        file_data = {
            'positions': [
                {
                    'sets_id': sets_id,
                    'timestamp': arrival_time
                }
            ]
        }

    with open(download_path, 'w') as outfile:
        json.dump(file_data, outfile)

    s3_client.upload_file(download_path, bucket, path)

    management_log['update_position_file'] = {'sets_id': sets_id, 'timestamp': timestamp, 'position_file_exists': position_file_exists}


def validate_requests(response, check, set_name=None):
    if check == 'events':
        if type(response) == type({}):
            if 'returnedCount' in response.keys():
                if response['returnedCount'] != 0:
                    return True
                else:
                    management_log["error"].append(f"No logs received for set = {set_name}")
                    return False
            else:
                management_log["error"].append(f"No logs received for set = {set_name}")
                return False
        else:
            management_log["error"].append(response)
            return False
    elif check == 'auth':
        if type(response) == type({}):
            if 'EPMAuthenticationResult' in response.keys():
                return True
            else:
                management_log["error"].append("No Authentication token received")
                return False
        else:
            management_log["error"].append(response)
            return False

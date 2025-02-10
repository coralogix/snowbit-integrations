import json
import time
import requests
import tempfile
import os
import logging
from datetime import datetime, timezone

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Configuration from environment variables
LOCK_FILE = os.path.join(tempfile.gettempdir(), "jumpcloud_to_coralogix.lock")

# Create lock file
def create_lock():
    if os.path.exists(LOCK_FILE):
        logging.error("ERROR: Only one instance is allowed")
        exit(1)
    with open(LOCK_FILE, "w") as f:
        f.write(str(datetime.now(timezone.utc)))

# Remove lock file
def remove_lock():
    if os.path.exists(LOCK_FILE):
        os.remove(LOCK_FILE)

# Get JumpCloud events
def get_jumpcloud_events(api_key, start_time, end_time, service_list):
    headers = {
        "x-api-key": api_key,
        "content-type": "application/json",
        "user-agent": "JumpCloud_AWSServerless.DirectoryInsights/1.3.2"
    }
    url = "https://api.jumpcloud.com/insights/directory/v1/events"
    all_events = []
    
    for service in service_list:
        body = {
            "service": [service],
            "start_time": start_time,
            "end_time": end_time,
            "limit": 10000
        }
        response = requests.post(url, headers=headers, json=body)
        logging.info(f"JumpCloud Response: {response.status_code}")
        response.raise_for_status()
        all_events.extend(response.json())
    
    return all_events

# Send logs to Coralogix
def send_to_coralogix(events, coralogix_key, coralogix_url, app_name, subsystem_name):
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {coralogix_key}"
    }
    for event in events:
        payload = [{
            "applicationName": app_name,
            "subsystemName": subsystem_name,
            "computerName": "jumpcloud_server",
            "severity": 3,
            "text": json.dumps(event)
        }]
        logging.info("Sending event to Coralogix")
        response = requests.post(coralogix_url, headers=headers, json=payload)
        logging.info(f"Coralogix Response: {response.status_code}")
        response.raise_for_status()

# Main function
def main():
    create_lock()
    try:
        api_key = os.getenv("JUMPCLOUD_API_KEY", "")
        coralogix_key = os.getenv("CORALOGIX_PRIVATE_KEY", "")
        coralogix_domain = os.getenv("CORALOGIX_DOMAIN", "")
        coralogix_url = f"https://ingress.{coralogix_domain}/logs/v1/singles"
        app_name = os.getenv("CORALOGIX_APP_NAME", "JumpCloudLogs")
        subsystem_name = os.getenv("CORALOGIX_SUBSYSTEM_NAME", "DirectoryInsights-logs")
        service_list = ["all"]  # Hardcoded to match all services
        
        start_time = datetime.now(timezone.utc).isoformat()  # Start from current timestamp
        
        while True:
            end_time = datetime.now(timezone.utc).isoformat()
            
            logging.info(f"Fetching events from {start_time} to {end_time}")
            events = get_jumpcloud_events(api_key, start_time, end_time, service_list)
            if events:
                logging.info(f"Fetched {len(events)} events")
                send_to_coralogix(events, coralogix_key, coralogix_url, app_name, subsystem_name)
            else:
                logging.info("No events to send")
            
            start_time = end_time  # Move start time forward for next iteration
            time.sleep(15)  # Run every 15 seconds
    
    finally:
        remove_lock()

if __name__ == "__main__":
    main()

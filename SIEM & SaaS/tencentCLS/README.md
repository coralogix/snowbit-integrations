# Tencent CLS to Coralogix Forwarder

A single-file Python script that consumes logs from a Tencent Cloud CLS log topic and forwards them to Coralogix. Each CLS log record is shipped to Coralogix as an individual JSON event.

Uses the CLS consumer-group SDK, so the server tracks offsets for us — no duplicates, no missing logs, no local state files, and safe to run alongside any other consumer on the same topic (as long as it uses a different `consumer_group_name`).

---

## How it works

1. Connects to a Tencent CLS log topic using the provided credentials.
2. Pulls new log records as they arrive (server-side offset tracking).
3. Converts each record to a Coralogix `/singles` payload entry.
4. Batches up to 500 records (or 1.5 MB) per POST and ships them.
5. Commits the offset to CLS only after Coralogix accepts the batch.
6. On any failure, the offset is **not** advanced, so the same data is replayed on the next pull.
7. Logs a one-line `STATS` summary every 60 seconds.

---

## Requirements

- Linux host with outbound HTTPS access to:
  - `*.cls.tencentcs.com` (Tencent CLS)
  - `ingress.<your-coralogix-domain>` (Coralogix ingestion)
- Python 3.8 or newer
- A Tencent Cloud sub-account with read access to the target CLS logset/topic
- A Coralogix "Send Your Data" API key

---

## Install

````bash
# 1. Install system dependencies
sudo apt update && sudo apt install -y python3-pip git

# 2. Install Python packages
sudo pip3 install --break-system-packages requests \
  git+https://github.com/TencentCloud/tencentcloud-cls-sdk-python.git

# 3. Prepare the working directory and drop forwarder.py into it
sudo mkdir -p /opt/cls-forwarder
sudo cp forwarder.py /opt/cls-forwarder/

# 4. Verify the packages loaded correctly
python3 -c "from tencentcloud.log.consumer import ConsumerWorker, LogHubConfig, ConsumerProcessorBase; import requests; print('ok')"
````

You should see `ok`.

> **Note:** The pip package is `tencentcloud-cls-sdk-python`, but the actual Python import is `tencentcloud.log.consumer` — a namespace package. This is normal for Tencent's SDKs.

---

## Configure

Open `forwarder.py` and fill in the values at the top of the file:

| Variable                     | What it is                                                                    | Where to get it                                                                                             |
| ---------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `TC_SECRET_ID`               | Tencent API key ID                                                            | Tencent Console → CAM → API Keys                                                                            |
| `TC_SECRET_KEY`              | Tencent API key secret                                                        | Same page as above                                                                                          |
| `TC_ENDPOINT`                | CLS data-plane host, format `<region>.cls.tencentcs.com`                      | Based on your region (e.g. `ap-mumbai.cls.tencentcs.com`)                                                   |
| `TC_REGION`                  | Region code                                                                   | CLS Console region selector (e.g. `ap-mumbai`)                                                              |
| `TC_LOGSET_ID`               | Logset UUID                                                                   | CLS Console → Logsets                                                                                       |
| `TC_TOPIC_IDS`               | List of topic UUIDs to consume                                                | CLS Console → Log Topics                                                                                    |
| `TC_INITIAL_START_TIME_UTC`  | First-run start position (`"end"`, `"begin"`, or `"YYYY-MM-DD HH:MM:SS"` UTC) | `"end"` for fresh deploys                                                                                   |
| `TC_CONSUMER_GROUP`          | Unique consumer group name for this forwarder                                 | Anything unique — **must not match any other consumer** reading the same topic                              |
| `TC_CONSUMER_NAME`           | Unique name within the consumer group                                         | Free-form; use different names if you run multiple replicas                                                 |
| `CORALOGIX_KEY`              | Send-Your-Data API key                                                        | Coralogix UI → Data Flow → API Keys                                                                         |
| `CORALOGIX_DOMAIN`           | Regional domain                                                               | `coralogix.in` (AP1), `coralogixsg.com` (AP2), `coralogix.com` (US1/EU1), `coralogix.us`, `eu2.coralogix.com` |
| `APP_NAME`, `SUBSYSTEM_NAME` | Tags under which logs appear in Coralogix                                     | Choose freely                                                                                               |

> **Important:** `TC_CONSUMER_GROUP` must be unique to this forwarder. If another system is already reading from the same topic using a different consumer group, both will receive a full copy of every log. If they share the same group name, CLS will split the partitions between them and each will see only part of the stream.

---

## Run manually (foreground, for testing)

````bash
cd /opt/cls-forwarder && python3 forwarder.py
````

You should see output like:

````
2026-04-22 19:40:03 INFO Starting group=coralogix-forwarder name=coralogix-forwarder-1 topics=['aaaa-...'] start=end
2026-04-22 19:40:04 INFO Processor initialized topic=aaaa-...
2026-04-22 19:40:06 INFO Coralogix accepted batch=142 status=202
2026-04-22 19:40:06 INFO Cycle complete topic=aaaa-... fetched=142
2026-04-22 19:41:03 INFO STATS uptime=60s fetched=957 forwarded=957 batches_ok=4 batches_failed=0 coralogix_status={202: 4} last_error=''
````

Stop with `Ctrl+C`.

---

## Run as a systemd service

### One-liner install

Paste the whole block in one go (creates the unit file and starts the service):

````bash
sudo tee /etc/systemd/system/cls-forwarder.service >/dev/null <<'EOF' && sudo systemctl daemon-reload && sudo systemctl enable --now cls-forwarder
[Unit]
Description=Tencent CLS to Coralogix forwarder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/cls-forwarder
ExecStart=/usr/bin/python3 -u /opt/cls-forwarder/forwarder.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
````

### Manage the service

````bash
sudo systemctl status cls-forwarder          # check status
sudo journalctl -u cls-forwarder -n 100      # view last 100 log lines
sudo systemctl restart cls-forwarder         # restart after config change
sudo systemctl stop cls-forwarder            # stop
sudo systemctl disable --now cls-forwarder   # stop and disable on boot
````

### Updating config

After editing `forwarder.py`:

````bash
sudo systemctl restart cls-forwarder
````

### Uninstall

````bash
sudo systemctl disable --now cls-forwarder && sudo rm /etc/systemd/system/cls-forwarder.service && sudo systemctl daemon-reload
````

---

## Verifying in Coralogix

In the Coralogix UI, go to **Explore** and filter by:

````
applicationName: "tencent" AND subsystemName: "cls"
````

You should see new records appearing within a minute of the service starting.

---

## Troubleshooting

| Symptom in logs                                                               | Likely cause                                              | Fix                                                                                                                         |
| ----------------------------------------------------------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `ModuleNotFoundError: No module named 'tencentcloud.log'`                     | SDK not installed, or wrong Python interpreter            | Re-run the `pip3 install` step; confirm `python3 -c "from tencentcloud.log.consumer import ConsumerWorker"` prints no error |
| `Coralogix auth failed: 401` or `403`                                         | Wrong API key or wrong `CORALOGIX_DOMAIN`                 | Confirm key type is "Send Your Data" and the domain matches your Coralogix team region                                      |
| `Failed to initialize consumer ... AuthFailure`                               | Wrong `TC_SECRET_ID` / `TC_SECRET_KEY`                    | Regenerate in CAM; make sure the sub-account has `QcloudCLSReadOnlyAccess` (or equivalent)                                  |
| `Failed to initialize consumer ... endpoint` / `RegionNotFound`               | Wrong `TC_ENDPOINT` or `TC_REGION`                        | Format is `<region>.cls.tencentcs.com` and region must match                                                                |
| Service runs but `fetched=0` over multiple STATS lines while logs are landing | Wrong `TC_LOGSET_ID` / `TC_TOPIC_IDS`, or no new data yet | Double-check IDs in the CLS Console; set `TC_INITIAL_START_TIME_UTC="begin"` for one run to test                            |
| Another system stopped receiving logs after you started this                  | Consumer group name collision                             | Change `TC_CONSUMER_GROUP` to something unique and restart                                                                  |
| `batches_failed` rising, `last_error='http 429 ...'`                          | Hitting Coralogix rate limit                              | Reduce `BATCH_MAX_RECORDS` or deploy fewer parallel replicas                                                                |
| Forwarder falling behind (ever-growing gap between `fetched` and wall time)   | One replica isn't enough                                  | Run additional replicas with the same `TC_CONSUMER_GROUP` but different `TC_CONSUMER_NAME` values                           |

---

## Scaling out

To handle higher throughput, run multiple replicas of this script with:

- The **same** `TC_CONSUMER_GROUP`
- **Different** `TC_CONSUMER_NAME` on each replica

CLS will automatically distribute the topic's partitions across them. As a rule of thumb, the number of replicas should equal the number of partitions on the topic.

---

## Operational notes

- Data loss: none under normal conditions. Offsets are committed only after Coralogix acknowledges a batch.
- Duplicates: a small number can occur if the process is killed between a successful Coralogix POST and the offset commit. Acceptable for audit/activity log use cases.
- Log age: Coralogix silently rejects records older than 24 hours at ingest. If you set `TC_INITIAL_START_TIME_UTC="begin"` on a long-retained topic, anything older than 24 h won't appear in Coralogix.
- Resource use: idle footprint around 40–80 MB RAM; a single replica handles a few thousand records per second comfortably on a 1-vCPU host.

````
````

# Tenable Audit → Coralogix log forwarder

A small, self-contained Python service that polls the Tenable Vulnerability
Management **activity log** endpoint and ships new events to Coralogix.

---

## Overview

- **Source:** `GET https://cloud.tenable.com/audit-log/v1/events` — returns
  Tenable activity log events (admin actions, API key usage, login events,
  configuration changes, etc.) for all users in your Tenable VM account.
  Tenable retains activity log data for 3 years.
- **Destination:** Coralogix logs singles endpoint
  (`https://ingress.<region>.coralogix.com/logs/v1/singles`).
- **Mechanism:** the forwarder polls on a fixed interval (default 5 minutes),
  fetches events strictly *after* the in-memory cursor, forwards them to
  Coralogix in batches, and advances the cursor in memory.

```
[ Tenable Cloud ]
       ↓ (REST, X-ApiKeys auth)
[ forwarder.py ]
       ↓ (HTTPS, Bearer auth, batched)
[ Coralogix ingress ]
```

The service is **stateless** — no local files are written. On startup it reads
events from `now - TN_INITIAL_LOOKBACK_HOURS` and advances from there in
memory. If the process restarts, it begins again from the same lookback
window. Set `TN_INITIAL_LOOKBACK_HOURS` at least slightly greater than
`POLL_INTERVAL_SECONDS` so you don't miss events across a restart.

---

## Prerequisites

- Python 3.9+
- Network egress to `cloud.tenable.com` and your Coralogix ingress endpoint
- A Tenable VM user with the **Administrator [64]** role (required by the
  activity log endpoint)
- A Tenable API key pair (`accessKey` + `secretKey`), generated in the Tenable
  UI under **My Account → API Keys → Generate**
- A Coralogix **Send-Your-Data API key**

Install the one runtime dependency:

```bash
pip install requests
```

---

## Configuration

All configuration lives at the top of `forwarder.py` in a clearly marked
block. Open the file in an editor and edit the values in place before
running — there are no environment variables, no separate config file.

The required fields (placeholders in the script):

| Variable                    | Description                                                                 |
| --------------------------- | --------------------------------------------------------------------------- |
| `TN_ACCESS_KEY`             | Tenable API access key                                                      |
| `TN_SECRET_KEY`             | Tenable API secret key                                                      |
| `CX_PRIVATE_KEY`            | Coralogix Send-Your-Data API key (`cxtp_…`)                                 |
| `CX_ENDPOINT`               | Region-specific ingress URL — see table below                               |

Optional fields (sensible defaults, tune if needed):

| Variable                    | Default                                               | Description                                                              |
| --------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------ |
| `TN_API_HOST`               | `https://cloud.tenable.com`                           | Override for FedRAMP / regional hosts                                    |
| `TN_PAGE_SIZE`              | `5000`                                                | Events per API call (API max is 5000)                                    |
| `TN_INITIAL_LOOKBACK_HOURS` | `1`                                                   | How far back to start pulling on every startup                           |
| `CX_APPLICATION_NAME`       | `tenable`                                             | `applicationName` on each shipped log                                    |
| `CX_SUBSYSTEM_NAME`         | `audit-log`                                           | `subsystemName` on each shipped log                                      |
| `BATCH_MAX_RECORDS`         | `500`                                                 | Max records per POST to Coralogix                                        |
| `POLL_INTERVAL_SECONDS`     | `300`                                                 | Seconds between Tenable API polls                                        |
| `LOG_LEVEL`                 | `INFO`                                                | `DEBUG` / `INFO` / `WARNING` / `ERROR`                                   |

### Coralogix endpoint by region

| Region | Ingress host                          |
| ------ | ------------------------------------- |
| US1    | `ingress.coralogix.us`                |
| US2    | `ingress.cx498.coralogix.com`         |
| EU1    | `ingress.coralogix.com`               |
| EU2    | `ingress.eu2.coralogix.com`           |
| AP1    | `ingress.coralogix.in`                |
| AP2    | `ingress.coralogixsg.com`             |
| AP3    | `ingress.ap3.coralogix.com`           |

Set `CX_ENDPOINT` to `https://<ingress-host>/logs/v1/singles` for your region.

---

## Running

### Run manually (foreground, for testing)

After editing the configuration block at the top of `forwarder.py`:

```bash
python3 forwarder.py
```

You should see log lines like:

```
2026-04-22T10:00:00+0000 INFO Starting Tenable → Coralogix audit log forwarder
2026-04-22T10:00:00+0000 INFO Initial cursor: 2026-04-22T09:00:00Z (lookback 1h)
2026-04-22T10:00:00+0000 INFO Querying Tenable audit log since 2026-04-22T09:00:00Z
2026-04-22T10:00:01+0000 INFO Fetched 37 event(s) from Tenable
2026-04-22T10:00:02+0000 INFO Shipped 37 record(s) to Coralogix
2026-04-22T10:00:02+0000 INFO Cursor advanced to 2026-04-22T09:59:41Z
```

### Run as a systemd service

Place the script at `/opt/tenable-forwarder/forwarder.py` (with the
configuration block already filled in), then create
`/etc/systemd/system/tenable-forwarder.service`:

```ini
[Unit]
Description=Tenable to Coralogix audit log forwarder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=tenable-forwarder
Group=tenable-forwarder
WorkingDirectory=/opt/tenable-forwarder
ExecStart=/usr/bin/python3 /opt/tenable-forwarder/forwarder.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Lock down the script so only the service user can read it (the API keys are
inside):

```bash
sudo chown tenable-forwarder:tenable-forwarder /opt/tenable-forwarder/forwarder.py
sudo chmod 600 /opt/tenable-forwarder/forwarder.py
```

Reload systemd and enable the service on boot:

```bash
sudo systemctl daemon-reload
sudo systemctl enable tenable-forwarder
```

### Managing the service

```bash
# start
sudo systemctl start tenable-forwarder

# stop
sudo systemctl stop tenable-forwarder

# restart (e.g. after editing the script)
sudo systemctl restart tenable-forwarder

# current status
sudo systemctl status tenable-forwarder

# last 100 log lines
sudo journalctl -u tenable-forwarder -n 100 --no-pager

# follow logs live (Ctrl+C to exit)
sudo journalctl -u tenable-forwarder -f

# logs since last boot
sudo journalctl -u tenable-forwarder -b

# disable on boot (stops auto-start, doesn't stop a running instance)
sudo systemctl disable tenable-forwarder
```

---

## Troubleshooting

| Symptom                                                                | Likely cause                                                | Fix                                                                                                         |
| ---------------------------------------------------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `Tenable auth failed — check TN_ACCESS_KEY / TN_SECRET_KEY`            | Wrong or expired API keys, or user lacks Administrator role | Regenerate keys in Tenable UI; confirm the user has role `[64]`                                             |
| `403 Forbidden` from Tenable                                           | User role too low                                           | Activity log endpoint requires Administrator role                                                           |
| `429 Too Many Requests` from Tenable                                   | Rate limit hit                                              | The built-in retry backs off automatically; also consider increasing `POLL_INTERVAL_SECONDS`                |
| `Coralogix rejected batch (401)`                                       | Wrong `CX_PRIVATE_KEY` or wrong region endpoint             | Confirm you're using a Send-Your-Data API key and `CX_ENDPOINT` matches your team's region                  |
| `Coralogix rejected batch (413)`                                       | Batch too large                                             | Reduce `BATCH_MAX_RECORDS`                                                                                  |
| Duplicate events after restart                                         | Lookback window overlaps with already-shipped events        | Expected — see "Operational notes". Deduplicate in Coralogix parsing rules if needed                        |
| Gap in events across a restart                                         | `TN_INITIAL_LOOKBACK_HOURS` shorter than downtime           | Increase `TN_INITIAL_LOOKBACK_HOURS`                                                                        |
| No new logs in Coralogix but forwarder reports success                 | Timestamps older than 24h are dropped by Coralogix          | Keep `TN_INITIAL_LOOKBACK_HOURS` ≤ 24                                                                       |

Enable `LOG_LEVEL=DEBUG` to see the full URL, params, and response bodies.

---

## Operational notes

- **Stateless:** the forwarder writes no files. The cursor lives only in
  memory; every restart begins from `now - TN_INITIAL_LOOKBACK_HOURS`.
- **Delivery semantics:** at-least-once. A process restart will re-ship every
  event within the lookback window, producing duplicates. Deduplicate in
  Coralogix (e.g., parsing rule that keys on the event `id`) if exact-once
  semantics are required.
- **Tuning the lookback:** set `TN_INITIAL_LOOKBACK_HOURS` equal to (or
  slightly greater than) the maximum downtime you expect between restarts.
  `1` is a reasonable default for a service that restarts rarely.
- **Log age at ingest:** Coralogix silently rejects records whose timestamp is
  older than 24 hours. Keep the lookback window below that.
- **Resource footprint:** idle ~40–60 MB RAM; a single instance comfortably
  handles the activity log volume of a typical Tenable tenant on a 1 vCPU host.
- **High availability:** run the service under `systemd` (or a container
  orchestrator) with automatic restart. Do **not** run multiple replicas
  pointing at the same Tenable tenant — they'll each fetch and ship the same
  events, producing as many duplicates as replicas.

---

## Event shape in Coralogix

Each shipped record has:

- `applicationName`: `tenable` (configurable)
- `subsystemName`: `audit-log` (configurable)
- `severity`: `3` (INFO)
- `timestamp`: the event's `received` time in milliseconds since epoch
- `text`: the full Tenable event as a compact JSON string

Example `text` payload (prettified for readability):

```json
{
  "id": "abc123",
  "action": "user.login",
  "crud": "c",
  "actor": { "id": "u-111", "name": "admin@example.com" },
  "target": { "id": "u-111", "name": "admin@example.com", "type": "user" },
  "description": null,
  "fields": [
    { "key": "X-Forwarded-For", "value": "203.0.113.5" },
    { "key": "source", "value": "UI" }
  ],
  "is_anonymous": null,
  "is_failure": false,
  "received": "2026-04-22T09:59:41Z"
}
```

Parse into structured fields in Coralogix with a JSON-extract parsing rule on
`applicationName = tenable AND subsystemName = audit-log`.

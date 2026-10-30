# Claude Compliance API → Coralogix

Ships activity logs from the Anthropic Compliance API (`/v1/compliance/activities`) into Coralogix as log entries.

- Incremental: tracks `last_seen_id` and `last_run_at` in a small state file, so each run only sends new activities.
- Two ways to run: **cron** (run once every N minutes) or **systemd service** (long-running loop).
- All settings read from environment variables first, with fallback values at the top of the script.

---

## 1. Requirements

- Linux VM (Ubuntu / Debian / Amazon Linux / RHEL — any with Python 3.8+)
- Outbound HTTPS to `api.anthropic.com` and `ingress.<your-domain>.coralogix.com`
- Anthropic **Compliance Access Key** (or Admin key)
- Coralogix **Send-Your-Data** API key

---

## 2. Install on the VM

```bash
# Python + venv
sudo apt update && sudo apt install -y python3 python3-venv          # Ubuntu/Debian
# sudo dnf install -y python3                                       # RHEL/Amazon Linux

# App directory
sudo mkdir -p /opt/claude-compliance/logs
sudo chown -R $USER:$USER /opt/claude-compliance
cd /opt/claude-compliance

# Copy the script here (scp, git, etc.), then:
python3 -m venv venv
./venv/bin/pip install --upgrade pip requests
chmod +x claude_compliance_to_coralogix.py
```

---

## 3. Configuration

### Required vs optional

Only **three** settings must be provided. Everything else has a sensible default.

| Must set | Why |
|---|---|
| `ANTHROPIC_COMPLIANCE_KEY` | Compliance Access Key (from claude.ai) or Admin API key (from Claude Console), with the `read:compliance_activities` scope |
| `CORALOGIX_API_KEY` | Coralogix **Send-Your-Data** key (Data Flow → API Keys) |
| `CORALOGIX_REGION` | Your Coralogix region — see the table below. Defaults to `AP1`; set it explicitly so you don't send logs to the wrong region |

Commonly changed (optional): `CORALOGIX_APP`, `CORALOGIX_SUBSYSTEM`, `STATE_FILE`.
Leave the rest at defaults unless you have a reason.

### Which region?

Match your Coralogix login URL to a region:

| Login URL | `CORALOGIX_REGION` | Location |
|---|---|---|
| `<team>.coralogix.com` | `EU1` | Ireland |
| `<team>.app.eu2.coralogix.com` | `EU2` | Stockholm |
| `<team>.app.coralogix.us` | `US1` | Ohio |
| `<team>.app.cx498.coralogix.com` | `US2` | Oregon |
| `<team>.app.us3.coralogix.com` | `US3` | Iowa (GCP) |
| `<team>.app.coralogix.in` | `AP1` | Mumbai |
| `<team>.app.coralogixsg.com` | `AP2` | Singapore |
| `<team>.app.ap3.coralogix.com` | `AP3` | Jakarta |

The script maps the region to the right ingress endpoint (`https://ingress.<region>.coralogix.com/logs/v1/singles`). For a custom or private domain, set `CORALOGIX_DOMAIN` (or the full `CORALOGIX_ENDPOINT`) instead — either one overrides the region.

### Where to put the values

Pick **one** of the two ways. Env vars always win over values in the file when both are set.

#### Way A — env file (recommended)

Keys stay out of the script, and the same file works for both cron and systemd.

```bash
nano /opt/claude-compliance/claude-compliance.env
```

```ini
ANTHROPIC_COMPLIANCE_KEY=sk-ant-admin-xxxxxxxx
CORALOGIX_API_KEY=cxtp_xxxxxxxx
CORALOGIX_REGION=AP1
CORALOGIX_APP=claude-compliance
CORALOGIX_SUBSYSTEM=activity-feed
STATE_FILE=/opt/claude-compliance/claude_compliance_state.json
```

```bash
chmod 600 /opt/claude-compliance/claude-compliance.env
```

Format: one `KEY=value` per line, no spaces around `=`, no quotes, no `export`. The same file is read by both the shell (cron) and systemd, so keep it plain.

#### Way B — edit the script directly (no env file)

Open the script and change the fallback value (second argument) in the `CONFIG` block at the top:

```python
ANTHROPIC_COMPLIANCE_KEY = cfg("ANTHROPIC_COMPLIANCE_KEY", "sk-ant-admin-xxxxxxxx")
CORALOGIX_API_KEY        = cfg("CORALOGIX_API_KEY", "cxtp_xxxxxxxx")
CORALOGIX_REGION         = cfg("CORALOGIX_REGION", "AP1").upper()
CORALOGIX_APP            = cfg("CORALOGIX_APP", "claude-compliance")
CORALOGIX_SUBSYSTEM      = cfg("CORALOGIX_SUBSYSTEM", "activity-feed")
STATE_FILE               = cfg("STATE_FILE", "/opt/claude-compliance/claude_compliance_state.json")
```

```bash
chmod 600 /opt/claude-compliance/claude_compliance_to_coralogix.py   # keys are now inside the script
```

With Way B, the cron line and the systemd unit are slightly simpler — sections 5 and 6 show both versions.

### All variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `ANTHROPIC_COMPLIANCE_KEY` | **Yes** | — | Compliance Access Key or Admin key |
| `CORALOGIX_API_KEY` | **Yes** | — | Send-Your-Data key |
| `CORALOGIX_REGION` | **Yes** | `AP1` | `EU1`, `EU2`, `US1`, `US2`, `US3`, `AP1`, `AP2`, `AP3` — see table above |
| `CORALOGIX_APP` | No | `claude-compliance` | `applicationName` in Coralogix |
| `CORALOGIX_SUBSYSTEM` | No | `activity-feed` | `subsystemName` in Coralogix |
| `CORALOGIX_COMPUTER` | No | `claude-compliance` | `computerName` in Coralogix |
| `CORALOGIX_SEVERITY` | No | `3` | 1 debug, 2 verbose, 3 info, 4 warn, 5 error, 6 critical |
| `CORALOGIX_DOMAIN` | No | *(from region)* | Custom/private domain, e.g. `mycompany.coralogix.com`. Overrides region |
| `CORALOGIX_ENDPOINT` | No | `https://ingress.<DOMAIN>/logs/v1/singles` | Full ingest URL override. Overrides region and domain |
| `ANTHROPIC_ACTIVITIES_URL` | No | `https://api.anthropic.com/v1/compliance/activities` | Compliance API endpoint |
| `ANTHROPIC_API_VERSION` | No | `2023-06-01` | `anthropic-version` header |
| `RUN_MODE` | No | `once` | `once` = run and exit (cron), `loop` = run forever (service) |
| `POLL_INTERVAL_SECONDS` | No | `300` | Sleep between cycles in `loop` mode |
| `LOOKBACK_MINUTES` | No | `5` | Fetch window on the very first run (no state file yet) |
| `OVERLAP_MINUTES` | No | `2` | Extra minutes re-checked on later runs (duplicates filtered by `last_seen_id`) |
| `SINCE` | No | *(empty)* | RFC3339 override, e.g. `2026-10-01T00:00:00Z` — useful for a one-time backfill |
| `STATE_FILE` | No | `claude_compliance_state.json` | Path to the state file (relative to the working directory) |
| `PAGE_LIMIT` | No | `1000` | Activities per Compliance API page (max 5000) |
| `SEND_CHUNK` | No | `100` | Activities per Coralogix POST |

---

## 4. Test run

```bash
cd /opt/claude-compliance

# Way A (env file)
set -a; . ./claude-compliance.env; set +a
./venv/bin/python claude_compliance_to_coralogix.py

# Way B (values in script)
./venv/bin/python claude_compliance_to_coralogix.py
```

Expected output:

```
2026-10-30 10:00:01Z Starting (mode=once, endpoint=https://ingress.ap1.coralogix.com/logs/v1/singles, ...)
2026-10-30 10:00:01Z Fetching activities since 2026-10-30T09:55:01Z (last_seen_id=None)
2026-10-30 10:00:02Z   page: fetched=42 sent=42 (running total sent=42)
2026-10-30 10:00:02Z Done. fetched=42 sent=42 newest_id=act_01...
```

Then check Coralogix → Explore → Logs, filter by `applicationName:claude-compliance`.

**One-time backfill** (e.g. last 7 days):

```bash
SINCE=2026-10-23T00:00:00Z ./venv/bin/python claude_compliance_to_coralogix.py
```

---

## 5. Option A — Run via crontab

Runs every 5 minutes, exits after each run.

```bash
crontab -e
```

Add **one** of these lines:

```cron
# Way A (env file)
*/5 * * * * cd /opt/claude-compliance && set -a && . ./claude-compliance.env && set +a && ./venv/bin/python claude_compliance_to_coralogix.py >> logs/cron.log 2>&1

# Way B (values in script)
*/5 * * * * cd /opt/claude-compliance && ./venv/bin/python claude_compliance_to_coralogix.py >> logs/cron.log 2>&1
```

Make sure `RUN_MODE` stays `once` (the default) — do not set it to `loop` for cron.

**View logs**

```bash
tail -f /opt/claude-compliance/logs/cron.log
```

**Check cron is active**

```bash
crontab -l
sudo systemctl status cron        # Ubuntu/Debian
sudo systemctl status crond       # RHEL/Amazon Linux
```

**Optional – log rotation** (`/etc/logrotate.d/claude-compliance`):

```
/opt/claude-compliance/logs/cron.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
```

---

## 6. Option B — Run as a Linux service (systemd)

Runs as a long-lived process, polls every `POLL_INTERVAL_SECONDS`, restarts automatically on failure or reboot. The loop mode is set inside the unit file, so the env file stays the same as in section 3.

Create the unit file (replace `ubuntu` with the user that owns `/opt/claude-compliance`):

```bash
sudo nano /etc/systemd/system/claude-compliance.service
```

```ini
[Unit]
Description=Claude Compliance API to Coralogix
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/claude-compliance
EnvironmentFile=/opt/claude-compliance/claude-compliance.env
Environment=RUN_MODE=loop
Environment=POLL_INTERVAL_SECONDS=300
ExecStart=/opt/claude-compliance/venv/bin/python /opt/claude-compliance/claude_compliance_to_coralogix.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Using Way B (values in script)? Delete the `EnvironmentFile=` line. Keep the two `Environment=` lines — they are what make the service loop.

**Enable and start**

```bash
sudo systemctl daemon-reload
sudo systemctl enable claude-compliance
sudo systemctl start claude-compliance
```

**Status**

```bash
sudo systemctl status claude-compliance
```

**View logs**

```bash
sudo journalctl -u claude-compliance -f            # follow live
sudo journalctl -u claude-compliance -n 100        # last 100 lines
sudo journalctl -u claude-compliance --since today
```

**Restart / stop**

```bash
sudo systemctl restart claude-compliance
sudo systemctl stop claude-compliance
```

**After changing the env file or script**

```bash
sudo systemctl restart claude-compliance
```

> Do not run cron and the service at the same time — pick one.

---

## 7. State file

`claude_compliance_state.json` stores:

```json
{
  "last_seen_id": "act_01...",
  "last_run_at": "2026-10-30T10:00:02Z"
}
```

- Each run fetches from `last_run_at − OVERLAP_MINUTES` and stops when it reaches `last_seen_id`, so nothing is sent twice.
- To re-send everything from a point in time, delete the state file and run once with `SINCE=...`.

---

## 8. Troubleshooting

| Symptom | Check |
|---|---|
| `ERROR: missing config: ...` | Env file not loaded or key empty. Run `set -a; . ./claude-compliance.env; set +a` first, or check `EnvironmentFile=` path. |
| `Compliance API error 401` | Wrong or expired Anthropic key, or key lacks compliance scope. |
| `Compliance API error 429` | Rate limited — script retries with backoff; increase `POLL_INTERVAL_SECONDS` or cron interval. |
| `ERROR: unknown CORALOGIX_REGION` | Typo in region — use one of `EU1 EU2 US1 US2 US3 AP1 AP2 AP3`. |
| `Coralogix error 401/403` | Wrong Send-Your-Data key, or key belongs to a team in a different region than `CORALOGIX_REGION`. |
| `Coralogix request failed` | VM has no outbound HTTPS to `ingress.<domain>.coralogix.com`. Test: `curl -I https://ingress.ap1.coralogix.com` |
| Nothing in Coralogix but `sent=N` | Check Explore time range and `applicationName` filter; ingest can lag a few seconds. |
| Service keeps restarting | `sudo journalctl -u claude-compliance -n 50` for the error. |

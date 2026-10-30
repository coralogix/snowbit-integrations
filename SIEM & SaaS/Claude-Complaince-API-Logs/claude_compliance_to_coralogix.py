#!/usr/bin/env python3
"""
Claude Compliance API -> Coralogix

Fetches activities from the Anthropic Compliance API and ships them to
Coralogix as log entries.

Runs in two modes (set RUN_MODE):
  once  - fetch and exit (use with cron)
  loop  - fetch, sleep POLL_INTERVAL_SECONDS, repeat (use with systemd)

Every setting below is read from the environment first. If the env var is
not set, the fallback value defined here is used.
"""

import os
import sys
import time
import json
import requests
from datetime import datetime, timedelta, timezone


# =============================================================================
# CONFIG
# Each value: os.environ.get("ENV_VAR") -> fallback value on the right.
# Edit the fallback values here, or set the env vars (see README).
# =============================================================================
def cfg(name, default=""):
    value = os.environ.get(name)
    return value if value not in (None, "") else default


# --- Anthropic Compliance API -----------------------------------------------
ANTHROPIC_COMPLIANCE_KEY = cfg("ANTHROPIC_COMPLIANCE_KEY", "")                 # Compliance Access Key or Admin key
ANTHROPIC_ACTIVITIES_URL = cfg("ANTHROPIC_ACTIVITIES_URL", "https://api.anthropic.com/v1/compliance/activities")
ANTHROPIC_API_VERSION    = cfg("ANTHROPIC_API_VERSION", "2023-06-01")

# --- Coralogix ---------------------------------------------------------------
CORALOGIX_API_KEY   = cfg("CORALOGIX_API_KEY", "")                             # Send-Your-Data key

# Region -> domain. Pick the region from your team login URL:
#   <team>.coralogix.com           -> EU1
#   <team>.app.eu2.coralogix.com   -> EU2
#   <team>.app.coralogix.us        -> US1
#   <team>.app.cx498.coralogix.com -> US2
#   <team>.app.us3.coralogix.com   -> US3
#   <team>.app.coralogix.in        -> AP1
#   <team>.app.coralogixsg.com     -> AP2
#   <team>.app.ap3.coralogix.com   -> AP3
CORALOGIX_REGIONS = {
    "EU1": "eu1.coralogix.com",   # AWS eu-west-1      (Ireland)
    "EU2": "eu2.coralogix.com",   # AWS eu-north-1     (Stockholm)
    "US1": "us1.coralogix.com",   # AWS us-east-2      (Ohio)
    "US2": "us2.coralogix.com",   # AWS us-west-2      (Oregon)
    "US3": "us3.coralogix.com",   # GCP us-central1    (Iowa)
    "AP1": "ap1.coralogix.com",   # AWS ap-south-1     (Mumbai)
    "AP2": "ap2.coralogix.com",   # AWS ap-southeast-1 (Singapore)
    "AP3": "ap3.coralogix.com",   # AWS ap-southeast-3 (Jakarta)
}

CORALOGIX_REGION    = cfg("CORALOGIX_REGION", "AP1").upper()                   # one of the keys above
CORALOGIX_DOMAIN    = cfg("CORALOGIX_DOMAIN", CORALOGIX_REGIONS.get(CORALOGIX_REGION, ""))  # optional: custom/private domain overrides region
CORALOGIX_ENDPOINT  = cfg("CORALOGIX_ENDPOINT", f"https://ingress.{CORALOGIX_DOMAIN}/logs/v1/singles")  # optional: full URL override
CORALOGIX_APP       = cfg("CORALOGIX_APP", "claude-compliance")                # applicationName
CORALOGIX_SUBSYSTEM = cfg("CORALOGIX_SUBSYSTEM", "activity-feed")              # subsystemName
CORALOGIX_COMPUTER  = cfg("CORALOGIX_COMPUTER", "claude-compliance")           # computerName
CORALOGIX_SEVERITY  = int(cfg("CORALOGIX_SEVERITY", "3"))                      # 1 debug, 2 verbose, 3 info, 4 warn, 5 error, 6 critical

# --- Run behaviour -----------------------------------------------------------
RUN_MODE              = cfg("RUN_MODE", "once")                                # "once" (cron) or "loop" (service)
POLL_INTERVAL_SECONDS = int(cfg("POLL_INTERVAL_SECONDS", "300"))               # loop mode only
LOOKBACK_MINUTES      = int(cfg("LOOKBACK_MINUTES", "5"))                      # first run (no state) fetch window
OVERLAP_MINUTES       = int(cfg("OVERLAP_MINUTES", "2"))                       # re-check window on later runs (dedup by last_seen_id)
SINCE                 = cfg("SINCE", "")                                       # optional RFC3339 override, e.g. 2026-10-01T00:00:00Z
STATE_FILE            = cfg("STATE_FILE", "claude_compliance_state.json")      # tracks last_seen_id + last_run_at
PAGE_LIMIT            = int(cfg("PAGE_LIMIT", "1000"))                         # per Compliance API page (max 5000)
SEND_CHUNK            = int(cfg("SEND_CHUNK", "100"))                          # activities per Coralogix POST
# =============================================================================


session = requests.Session()


def log(msg):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    print(f"{now} {msg}", flush=True)


def validate_config():
    missing = []
    if not ANTHROPIC_COMPLIANCE_KEY:
        missing.append("ANTHROPIC_COMPLIANCE_KEY")
    if not CORALOGIX_API_KEY:
        missing.append("CORALOGIX_API_KEY")
    if missing:
        sys.exit(f"ERROR: missing config: {', '.join(missing)} (set env var or edit fallback at top of file)")
    if not CORALOGIX_DOMAIN:
        sys.exit(f"ERROR: unknown CORALOGIX_REGION '{CORALOGIX_REGION}'. "
                 f"Use one of: {', '.join(CORALOGIX_REGIONS)} — or set CORALOGIX_DOMAIN / CORALOGIX_ENDPOINT directly")
    if RUN_MODE not in ("once", "loop"):
        sys.exit(f"ERROR: RUN_MODE must be 'once' or 'loop', got '{RUN_MODE}'")


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return {}


def save_state(state):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp, STATE_FILE)


def compute_since(state):
    """Priority: SINCE override -> last_run_at (minus overlap) -> lookback."""
    if SINCE:
        return SINCE
    last_run_at = state.get("last_run_at")
    if last_run_at:
        try:
            dt = datetime.fromisoformat(last_run_at.replace("Z", "+00:00"))
            return (dt - timedelta(minutes=OVERLAP_MINUTES)).strftime("%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            pass
    return (datetime.now(timezone.utc) - timedelta(minutes=LOOKBACK_MINUTES)).strftime("%Y-%m-%dT%H:%M:%SZ")


# -----------------------------------------------------------------------------
# Coralogix
# -----------------------------------------------------------------------------
def to_cx_entry(activity):
    ts = activity.get("created_at")
    try:
        ts_ms = int(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp() * 1000)
    except Exception:
        ts_ms = int(time.time() * 1000)
    return {
        "applicationName": CORALOGIX_APP,
        "subsystemName": CORALOGIX_SUBSYSTEM,
        "computerName": CORALOGIX_COMPUTER,
        "category": activity.get("type", "activity"),
        "severity": CORALOGIX_SEVERITY,
        "timestamp": ts_ms,
        "text": json.dumps(activity),
    }


def send_to_coralogix(activities):
    headers = {
        "Authorization": f"Bearer {CORALOGIX_API_KEY}",
        "Content-Type": "application/json",
    }
    sent = 0
    for i in range(0, len(activities), SEND_CHUNK):
        batch = [to_cx_entry(a) for a in activities[i:i + SEND_CHUNK]]
        for attempt in range(3):
            try:
                r = session.post(CORALOGIX_ENDPOINT, headers=headers, json=batch, timeout=60)
                if r.status_code in (200, 201, 202):
                    sent += len(batch)
                    break
                if r.status_code in (429, 502, 503, 504) and attempt < 2:
                    time.sleep(2 * (attempt + 1))
                    continue
                log(f"  Coralogix error {r.status_code}: {r.text[:200]}")
                break
            except requests.exceptions.RequestException as e:
                if attempt < 2:
                    time.sleep(2 * (attempt + 1))
                    continue
                log(f"  Coralogix request failed: {e}")
    return sent


# -----------------------------------------------------------------------------
# Anthropic Compliance API
# -----------------------------------------------------------------------------
def fetch_page(params):
    headers = {
        "x-api-key": ANTHROPIC_COMPLIANCE_KEY,
        "anthropic-version": ANTHROPIC_API_VERSION,
    }
    for attempt in range(5):
        try:
            r = session.get(ANTHROPIC_ACTIVITIES_URL, headers=headers, params=params, timeout=60)
            if r.status_code == 200:
                return r.json()
            if r.status_code in (429, 502, 503, 504):
                wait = 2 ** attempt * 5
                log(f"  {r.status_code} from Compliance API, retry in {wait}s")
                time.sleep(wait)
                continue
            raise RuntimeError(f"Compliance API error {r.status_code}: {r.text[:300]}")
        except requests.exceptions.RequestException as e:
            log(f"  request error: {e}")
            time.sleep(2 ** attempt * 5)
    raise RuntimeError("Compliance API: exhausted retries")


# -----------------------------------------------------------------------------
# One sync cycle
# -----------------------------------------------------------------------------
def run_once():
    state = load_state()
    last_seen_id = state.get("last_seen_id")
    since = compute_since(state)

    log(f"Fetching activities since {since} (last_seen_id={last_seen_id})")

    total_fetched = 0
    total_sent = 0
    newest_id = None
    after_id = None

    # Activities come newest-first. Page backwards with after_id=last_id,
    # stop at `since` (server-side) or at last_seen_id from the previous run.
    while True:
        params = {"limit": PAGE_LIMIT, "created_at.gte": since}
        if after_id:
            params["after_id"] = after_id

        page = fetch_page(params)
        data = page.get("data", [])
        if not data:
            break

        if newest_id is None:
            newest_id = page.get("first_id") or data[0].get("id")

        cut = None
        if last_seen_id:
            for idx, act in enumerate(data):
                if act.get("id") == last_seen_id:
                    cut = idx
                    break
        page_to_send = data[:cut] if cut is not None else data

        if page_to_send:
            sent = send_to_coralogix(page_to_send)
            total_fetched += len(page_to_send)
            total_sent += sent
            log(f"  page: fetched={len(page_to_send)} sent={sent} (running total sent={total_sent})")

        if cut is not None:
            log("  reached last_seen_id, stopping")
            break
        if not page.get("has_more"):
            break
        after_id = page.get("last_id")
        if not after_id:
            break

    if newest_id:
        state["last_seen_id"] = newest_id
    state["last_run_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    save_state(state)

    log(f"Done. fetched={total_fetched} sent={total_sent} newest_id={newest_id}")


def main():
    validate_config()
    log(f"Starting (mode={RUN_MODE}, endpoint={CORALOGIX_ENDPOINT}, app={CORALOGIX_APP}, subsystem={CORALOGIX_SUBSYSTEM})")

    if RUN_MODE == "once":
        run_once()
        return

    while True:
        try:
            run_once()
        except Exception as e:
            log(f"ERROR during sync: {e}")
        log(f"Sleeping {POLL_INTERVAL_SECONDS}s")
        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()

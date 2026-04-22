#!/usr/bin/env python3
"""
Tenable Vulnerability Management → Coralogix audit log forwarder.

Polls the Tenable activity-log endpoint on a fixed interval, paginates through
new events since the in-memory cursor, and forwards them to the Coralogix logs
singles endpoint in batches.

Reference:
    - Tenable API: https://developer.tenable.com/reference/audit-log-events
    - Coralogix logs API: https://coralogix.com/docs/log-query-language/send-your-data/
"""

from __future__ import annotations

import json
import logging
import signal
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


# ========================================================================== #
# Configuration — edit the values below before running.                      #
# ========================================================================== #

# --- Tenable ---------------------------------------------------------------
# Access + secret key pair from the Tenable UI:
#   My Account → API Keys → Generate
# The user must have the Administrator [64] role.
TN_ACCESS_KEY = "REPLACE_WITH_TENABLE_ACCESS_KEY"
TN_SECRET_KEY = "REPLACE_WITH_TENABLE_SECRET_KEY"

# Tenable API host. Change only if you're on a regional / FedRAMP host.
TN_API_HOST = "https://cloud.tenable.com"

# Events per API call. API max is 5000.
TN_PAGE_SIZE = 5000

# How far back in time to start pulling on startup. This is applied every
# time the process starts (the cursor is in-memory only).
# Set this ≥ your expected restart downtime so events aren't missed.
TN_INITIAL_LOOKBACK_HOURS = 1


# --- Coralogix -------------------------------------------------------------
# Send-Your-Data API key (starts with "cxtp_").
CX_PRIVATE_KEY = "REPLACE_WITH_CORALOGIX_SEND_YOUR_DATA_API_KEY"

# Region-specific ingress endpoint. Examples:
#   US1  https://ingress.coralogix.us/logs/v1/singles
#   US2  https://ingress.cx498.coralogix.com/logs/v1/singles
#   EU1  https://ingress.coralogix.com/logs/v1/singles
#   EU2  https://ingress.eu2.coralogix.com/logs/v1/singles
#   AP1  https://ingress.coralogix.in/logs/v1/singles
#   AP2  https://ingress.coralogixsg.com/logs/v1/singles
#   AP3  https://ingress.ap3.coralogix.com/logs/v1/singles
CX_ENDPOINT = "https://ingress.coralogix.com/logs/v1/singles"

# applicationName / subsystemName tags on every shipped log.
CX_APPLICATION_NAME = "tenable"
CX_SUBSYSTEM_NAME = "audit-log"

# Max records per POST to Coralogix. Lower this if you hit 413 errors.
BATCH_MAX_RECORDS = 500


# --- Runtime ---------------------------------------------------------------
# Seconds between polls of the Tenable API.
POLL_INTERVAL_SECONDS = 300

# Log verbosity: DEBUG / INFO / WARNING / ERROR
LOG_LEVEL = "INFO"

# ========================================================================== #
# End of configuration. No edits needed below this line.                     #
# ========================================================================== #


# ---------- Logging -------------------------------------------------------- #

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z",
)
log = logging.getLogger("tenable-forwarder")


# ---------- HTTP session with retries -------------------------------------- #

def build_session() -> requests.Session:
    s = requests.Session()
    retry = Retry(
        total=5,
        backoff_factor=1.5,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET", "POST"]),
        respect_retry_after_header=True,
    )
    s.mount("https://", HTTPAdapter(max_retries=retry))
    s.mount("http://", HTTPAdapter(max_retries=retry))
    return s


session = build_session()


# ---------- Tenable fetch -------------------------------------------------- #

def fetch_events(since_iso: str) -> list[dict[str, Any]]:
    """Fetch audit log events strictly after `since_iso` (ISO-8601 UTC)."""
    headers = {
        "Accept": "application/json",
        "X-ApiKeys": f"accessKey={TN_ACCESS_KEY};secretKey={TN_SECRET_KEY}",
    }
    params = {
        "f": f"date.gt:{since_iso}",
        "limit": TN_PAGE_SIZE,
        "sort": "date:asc",
    }
    url = f"{TN_API_HOST}/audit-log/v1/events"

    log.info("Querying Tenable audit log since %s", since_iso)
    resp = session.get(url, headers=headers, params=params, timeout=60)
    if resp.status_code == 401:
        log.error("Tenable auth failed — check TN_ACCESS_KEY / TN_SECRET_KEY")
        resp.raise_for_status()
    resp.raise_for_status()

    data = resp.json()
    events = data.get("events", [])
    log.info("Fetched %d event(s) from Tenable", len(events))
    return events


# ---------- Coralogix send ------------------------------------------------- #

def to_coralogix_record(event: dict[str, Any]) -> dict[str, Any]:
    event_time = event.get("received") or event.get("date")
    try:
        ts = int(datetime.strptime(event_time, "%Y-%m-%dT%H:%M:%SZ")
                 .replace(tzinfo=timezone.utc).timestamp() * 1000)
    except (TypeError, ValueError):
        ts = int(time.time() * 1000)

    return {
        "applicationName": CX_APPLICATION_NAME,
        "subsystemName": CX_SUBSYSTEM_NAME,
        "severity": 3,
        "timestamp": ts,
        "text": json.dumps(event, separators=(",", ":")),
    }


def ship_batch(records: list[dict[str, Any]]) -> None:
    if not records:
        return
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {CX_PRIVATE_KEY}",
    }
    resp = session.post(CX_ENDPOINT, headers=headers,
                        data=json.dumps(records), timeout=30)
    if resp.status_code >= 300:
        log.error("Coralogix rejected batch (%d): %s",
                  resp.status_code, resp.text[:500])
        resp.raise_for_status()
    log.info("Shipped %d record(s) to Coralogix", len(records))


def ship_events(events: list[dict[str, Any]]) -> None:
    batch: list[dict[str, Any]] = []
    for ev in events:
        batch.append(to_coralogix_record(ev))
        if len(batch) >= BATCH_MAX_RECORDS:
            ship_batch(batch)
            batch = []
    ship_batch(batch)


# ---------- Main loop ------------------------------------------------------ #

_shutdown = False


def _handle_signal(signum: int, _frame: Any) -> None:
    global _shutdown
    log.info("Received signal %d, shutting down after current cycle", signum)
    _shutdown = True


def main() -> int:
    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    log.info("Starting Tenable → Coralogix audit log forwarder")
    log.info("Poll interval: %ds, batch size: %d",
             POLL_INTERVAL_SECONDS, BATCH_MAX_RECORDS)

    cursor = (datetime.now(timezone.utc) - timedelta(hours=TN_INITIAL_LOOKBACK_HOURS)) \
        .strftime("%Y-%m-%dT%H:%M:%SZ")
    log.info("Initial cursor: %s (lookback %dh)", cursor, TN_INITIAL_LOOKBACK_HOURS)

    while not _shutdown:
        try:
            events = fetch_events(cursor)
            if events:
                ship_events(events)
                latest = events[-1].get("received") or events[-1].get("date") or cursor
                cursor = latest
                log.info("Cursor advanced to %s", cursor)
        except requests.HTTPError as e:
            log.error("HTTP error during cycle: %s", e)
        except Exception as e:  # noqa: BLE001
            log.exception("Unexpected error during cycle: %s", e)

        # Sleep in 1s chunks so SIGTERM is handled promptly.
        for _ in range(POLL_INTERVAL_SECONDS):
            if _shutdown:
                break
            time.sleep(1)

    log.info("Forwarder stopped cleanly")
    return 0


if __name__ == "__main__":
    sys.exit(main())

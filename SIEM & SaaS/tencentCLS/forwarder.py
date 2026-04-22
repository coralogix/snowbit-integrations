"""
Tencent CLS to Coralogix forwarder.

Consumes logs from a Tencent CLS log topic using the CLS consumer-group SDK
and forwards each log record to Coralogix as an individual JSON event.
"""

import json
import logging
import signal
import sys
import threading
import time
from collections import defaultdict

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from tencentcloud_cls_sdk_python.consumer import (
    ConsumerProcessorBase,
    ConsumerWorker,
    LogHubConfig,
)


# =========================================================================
# CONFIGURATION
# =========================================================================

# --- Tencent Cloud credentials ---
# CAM -> API Keys: https://console.tencentcloud.com/cam/capi
# Recommended: a sub-account with policy "QcloudCLSReadOnlyAccess".
TC_SECRET_ID  = "AKID_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
TC_SECRET_KEY = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# CLS data-plane endpoint for the region your topic lives in.
# Format: "<region>.cls.tencentcs.com"
# Examples: ap-mumbai.cls.tencentcs.com, ap-singapore.cls.tencentcs.com,
#           ap-hongkong.cls.tencentcs.com, ap-guangzhou.cls.tencentcs.com
TC_ENDPOINT = "ap-mumbai.cls.tencentcs.com"

# Region code matching the endpoint above.
TC_REGION = "" #ap-mumbai

# Logset ID from CLS Console -> Logsets.
TC_LOGSET_ID = "00000000-1111-2222-3333-444444444444"

# Topic IDs from CLS Console -> Log Topics.
TC_TOPIC_IDS = [
    "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
]

# First-run start position. Only affects the first run for a given
# consumer_group_name; after that the server remembers the offset.
#   "end"   -> start from "now"
#   "begin" -> start from earliest retained data
#   "YYYY-MM-DD HH:MM:SS" (UTC) or integer unix-seconds as a string
TC_INITIAL_START_TIME_UTC = "end"

# Must be unique to this forwarder. Do not reuse the name of any other
# consumer reading the same topic, or partitions will be split between them.
TC_CONSUMER_GROUP = "coralogix-forwarder"
TC_CONSUMER_NAME  = "coralogix-forwarder-1"

# --- Coralogix ---
# Data Flow -> API Keys -> "Send Your Data".
CORALOGIX_KEY = "cxtp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Regional domain:
#   coralogix.in         AP1 (India)
#   coralogixsg.com      AP2 (Singapore)
#   coralogix.com        US1 / EU1
#   coralogix.us         US2
#   eu2.coralogix.com    EU2
CORALOGIX_DOMAIN = "" #coralogix.in
CORALOGIX_URL    = f"https://ingress.{CORALOGIX_DOMAIN}/logs/v1/singles"

APP_NAME       = "tencent"
SUBSYSTEM_NAME = "cls"

# --- Batching (Coralogix /singles caps at 2 MB per request) ---
BATCH_MAX_RECORDS = 500
BATCH_MAX_BYTES   = 1_500_000

# --- Stats reporting cadence (seconds) ---
STATS_INTERVAL_SECONDS = 60

# =========================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("forwarder")


# =========================================================================
# Stats
# =========================================================================
class Stats:
    """Thread-safe counters covering the life of the process."""

    def __init__(self):
        self._lock = threading.Lock()
        self.started_at         = time.time()
        self.events_fetched     = 0
        self.events_forwarded   = 0
        self.batches_sent       = 0
        self.batches_failed     = 0
        self.coralogix_status   = defaultdict(int)
        self.last_error         = ""
        self.last_error_at      = 0.0

    def add_fetched(self, n):
        with self._lock:
            self.events_fetched += n

    def add_forwarded(self, n, status_code):
        with self._lock:
            self.events_forwarded += n
            self.batches_sent += 1
            self.coralogix_status[status_code] += 1

    def add_failed_batch(self, err):
        with self._lock:
            self.batches_failed += 1
            self.last_error = str(err)[:300]
            self.last_error_at = time.time()

    def snapshot(self):
        with self._lock:
            return {
                "uptime_sec":       int(time.time() - self.started_at),
                "events_fetched":   self.events_fetched,
                "events_forwarded": self.events_forwarded,
                "batches_sent":     self.batches_sent,
                "batches_failed":   self.batches_failed,
                "coralogix_status": dict(self.coralogix_status),
                "last_error":       self.last_error,
            }


STATS = Stats()


# =========================================================================
# Coralogix sender
# =========================================================================
def _make_session():
    s = requests.Session()
    retry = Retry(
        total=5,
        backoff_factor=1.0,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("POST",),
        raise_on_status=False,
    )
    s.mount("https://", HTTPAdapter(max_retries=retry, pool_connections=4, pool_maxsize=8))
    s.headers.update({
        "Authorization": f"Bearer {CORALOGIX_KEY}",
        "Content-Type":  "application/json",
    })
    return s


def _post_batch(session, batch):
    """POST one batch to Coralogix. Returns HTTP status code. Raises on non-2xx."""
    if not batch:
        return None

    body = json.dumps(batch, ensure_ascii=False).encode("utf-8")

    try:
        r = session.post(CORALOGIX_URL, data=body, timeout=30)
    except requests.exceptions.ConnectionError as e:
        STATS.add_failed_batch(f"connection error: {e}")
        log.error("Coralogix connection error (batch=%d): %s", len(batch), e)
        raise
    except requests.exceptions.Timeout as e:
        STATS.add_failed_batch(f"timeout: {e}")
        log.error("Coralogix request timed out (batch=%d): %s", len(batch), e)
        raise
    except requests.exceptions.RequestException as e:
        STATS.add_failed_batch(f"request error: {e}")
        log.error("Coralogix request error (batch=%d): %s", len(batch), e)
        raise

    if r.status_code == 401 or r.status_code == 403:
        STATS.add_failed_batch(f"auth failed: {r.status_code}")
        log.error("Coralogix auth failed: %d %s  (check CORALOGIX_KEY and CORALOGIX_DOMAIN)",
                  r.status_code, r.text[:200])
        r.raise_for_status()

    if r.status_code >= 300:
        STATS.add_failed_batch(f"http {r.status_code}: {r.text[:200]}")
        log.error("Coralogix rejected batch=%d status=%d body=%s",
                  len(batch), r.status_code, r.text[:300])
        r.raise_for_status()

    STATS.add_forwarded(len(batch), r.status_code)
    log.info("Coralogix accepted batch=%d status=%d", len(batch), r.status_code)
    return r.status_code


# =========================================================================
# Consumer processor
# =========================================================================
class Forwarder(ConsumerProcessorBase):

    def initialize(self, topic_id):
        self.topic_id = topic_id
        self.session  = _make_session()
        log.info("Processor initialized topic=%s", topic_id)

    def process(self, log_groups, offset_tracker):
        batch = []
        batch_bytes = 0
        fetched_this_call = 0

        try:
            for lg in log_groups:
                source   = getattr(lg, "source",   "") or ""
                filename = getattr(lg, "filename", "") or ""

                for entry in lg.logs:
                    fetched_this_call += 1

                    t = int(entry.time)
                    if   t > 10**15: ts_ms = t // 1000
                    elif t > 10**12: ts_ms = t
                    else:            ts_ms = t * 1000

                    fields = {c.key: c.value for c in entry.contents}

                    record = {
                        "applicationName": APP_NAME,
                        "subsystemName":   SUBSYSTEM_NAME,
                        "severity":        3,
                        "timestamp":       ts_ms,
                        "text":            json.dumps(fields, ensure_ascii=False),
                        "computerName":    source,
                        "category":        filename,
                    }

                    rec_bytes = len(json.dumps(record, ensure_ascii=False).encode("utf-8"))

                    if batch and (
                        len(batch) >= BATCH_MAX_RECORDS
                        or batch_bytes + rec_bytes > BATCH_MAX_BYTES
                    ):
                        _post_batch(self.session, batch)
                        batch, batch_bytes = [], 0

                    batch.append(record)
                    batch_bytes += rec_bytes

            if batch:
                _post_batch(self.session, batch)

        except Exception as e:
            STATS.add_fetched(fetched_this_call)
            log.error("process() failed topic=%s fetched_this_call=%d err=%s",
                      self.topic_id, fetched_this_call, e)
            # Do not advance the offset, so the SDK will replay.
            try:
                offset_tracker.save_offset(False)
            except Exception:
                pass
            return None

        STATS.add_fetched(fetched_this_call)
        log.info("Cycle complete topic=%s fetched=%d",
                 self.topic_id, fetched_this_call)

        try:
            offset_tracker.save_offset(True)
        except Exception as e:
            log.error("save_offset failed topic=%s err=%s", self.topic_id, e)

    def shutdown(self):
        try:
            self.session.close()
        except Exception:
            pass
        log.info("Processor shutdown topic=%s", self.topic_id)


# =========================================================================
# Stats reporter
# =========================================================================
def stats_reporter(stop_flag):
    while not stop_flag["v"]:
        time.sleep(STATS_INTERVAL_SECONDS)
        s = STATS.snapshot()
        log.info(
            "STATS uptime=%ss fetched=%d forwarded=%d batches_ok=%d "
            "batches_failed=%d coralogix_status=%s last_error=%r",
            s["uptime_sec"], s["events_fetched"], s["events_forwarded"],
            s["batches_sent"], s["batches_failed"],
            s["coralogix_status"], s["last_error"],
        )


# =========================================================================
# Main
# =========================================================================
def main():
    if not TC_SECRET_ID or not TC_SECRET_KEY:
        log.error("Missing TC_SECRET_ID / TC_SECRET_KEY")
        sys.exit(2)
    if not CORALOGIX_KEY or CORALOGIX_KEY.startswith("cxtp_xxxxxxxx"):
        log.error("Missing or placeholder CORALOGIX_KEY")
        sys.exit(2)
    if not TC_TOPIC_IDS:
        log.error("TC_TOPIC_IDS is empty")
        sys.exit(2)

    try:
        cfg = LogHubConfig(
            endpoint                 = TC_ENDPOINT,
            access_key_id            = TC_SECRET_ID,
            access_key               = TC_SECRET_KEY,
            region                   = TC_REGION,
            logset_id                = TC_LOGSET_ID,
            topic_ids                = TC_TOPIC_IDS,
            consumer_group_name      = TC_CONSUMER_GROUP,
            consumer_name            = TC_CONSUMER_NAME,
            heartbeat_interval       = 20,
            data_fetch_interval      = 2,
            offset_start_time        = TC_INITIAL_START_TIME_UTC,
            max_fetch_log_group_size = 2 * 1024 * 1024,
        )
    except Exception as e:
        log.error("Invalid LogHubConfig: %s", e)
        sys.exit(2)

    try:
        worker = ConsumerWorker(Forwarder, consumer_option=cfg)
    except Exception as e:
        # Usually signals bad credentials, wrong region/endpoint, or a
        # permissions problem on the logset/topic.
        log.error("Failed to initialize consumer (check credentials, "
                  "endpoint, region, logset/topic permissions): %s", e)
        sys.exit(3)

    stop_flag = {"v": False}

    def on_signal(signum, _frame):
        log.warning("Signal %s received, shutting down", signum)
        stop_flag["v"] = True

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT,  on_signal)

    reporter = threading.Thread(target=stats_reporter, args=(stop_flag,), daemon=True)
    reporter.start()

    log.info("Starting group=%s name=%s topics=%s start=%s",
             TC_CONSUMER_GROUP, TC_CONSUMER_NAME, TC_TOPIC_IDS, TC_INITIAL_START_TIME_UTC)

    try:
        worker.start()
    except Exception as e:
        log.error("Consumer worker failed to start: %s", e)
        sys.exit(3)

    while not stop_flag["v"]:
        time.sleep(1)

    try:
        worker.shutdown()
    except Exception as e:
        log.error("Worker shutdown error: %s", e)

    final = STATS.snapshot()
    log.info(
        "FINAL uptime=%ss fetched=%d forwarded=%d batches_ok=%d batches_failed=%d",
        final["uptime_sec"], final["events_fetched"], final["events_forwarded"],
        final["batches_sent"], final["batches_failed"],
    )
    sys.exit(0)


if __name__ == "__main__":
    main()

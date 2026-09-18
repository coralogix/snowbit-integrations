"""
GCS Cloudflare Logpush files to Coralogix Logs API.

Triggered by Cloud Storage Object Finalize (Cloud Functions 2nd gen / Eventarc).
Reads gzipped or plain NDJSON written by Cloudflare Logpush, then POSTs each
line as a log to Coralogix.

Typical Logpush layout:

  gs://<bucket>/<optional-prefix>/<YYYYMMDD>/<HHMMSS>_<id>.log.gz

Each line is one JSON object (HTTP requests, firewall events, audit, DNS, etc.).
"""

from __future__ import annotations

import gzip
import json
import logging
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, Iterator, List, Optional, Tuple

import functions_framework
from cloudevents.http import CloudEvent
from google.cloud import storage

LOGGER = logging.getLogger()
LOGGER.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())

CORALOGIX_BATCH_SIZE = int(os.getenv("CORALOGIX_BATCH_SIZE", "400"))
CORALOGIX_TIMEOUT_SECONDS = float(os.getenv("CORALOGIX_TIMEOUT_SECONDS", "60"))
MAX_RETRIES = int(os.getenv("CORALOGIX_MAX_RETRIES", "4"))
KEY_PREFIX = os.getenv("GCS_KEY_PREFIX", os.getenv("S3_KEY_PREFIX", "")).strip()
KEY_SUFFIX = os.getenv("GCS_KEY_SUFFIX", "").strip().lower()
DRY_RUN = os.getenv("DRY_RUN", "").strip().lower() in {"1", "true", "yes"}
INCLUDE_SOURCE_METADATA = os.getenv("INCLUDE_SOURCE_METADATA", "").strip().lower() in {
    "1",
    "true",
    "yes",
}

_storage_client: Optional[storage.Client] = None


def _storage() -> storage.Client:
    global _storage_client
    if _storage_client is None:
        _storage_client = storage.Client()
    return _storage_client


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _coralogix_url() -> str:
    domain = os.getenv("CORALOGIX_DOMAIN", "coralogix.com").strip().lstrip(".")
    return f"https://ingress.{domain}/logs/v1/bulk"


def _api_key() -> str:
    return (
        os.getenv("CORALOGIX_SEND_YOUR_DATA_KEY", "").strip()
        or os.getenv("CORALOGIX_PRIVATE_KEY", "").strip()
        or _require_env("CORALOGIX_SEND_YOUR_DATA_KEY")
    )


def _application() -> str:
    return os.getenv(
        "CORALOGIX_APPLICATION_NAME",
        os.getenv("CORALOGIX_APPLICATION", "cloudflare"),
    )


def _subsystem() -> str:
    return os.getenv(
        "CORALOGIX_SUBSYSTEM_NAME",
        os.getenv("CORALOGIX_SUBSYSTEM", "logpush"),
    )


@functions_framework.cloud_event
def ship_cloudflare_logs(cloud_event: CloudEvent) -> None:
    """Eventarc / GCS finalize entry point (Cloud Functions 2nd gen)."""
    result = process_event(cloud_event.data or {}, dict(cloud_event))
    LOGGER.info("Done %s", result)
    if not result.get("ok"):
        raise RuntimeError(f"Failed to ship Cloudflare logs: {result}")


@functions_framework.http
def backfill(request: Any) -> Tuple[str, int]:
    """
    HTTP entry point for historic objects the GCS trigger never saw.

    POST JSON: {"bucket": "my-bucket", "name": "logs/20260918/file.log.gz"}
    """
    payload = request.get_json(silent=True) or {}
    if request.args:
        payload.update({k: v for k, v in request.args.items() if v})
    result = process_event(payload, payload)
    status = 200 if result.get("ok") else 500
    return json.dumps(result), status


def process_event(data: Dict[str, Any], raw_event: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    objects = extract_gcs_objects(data, raw_event or {})
    if not objects:
        LOGGER.info("No GCS objects in event")
        return {"ok": True, "files": 0, "events": 0, "sent": 0}

    total_events = 0
    total_sent = 0
    processed: List[Dict[str, Any]] = []

    for bucket, name in objects:
        if not should_process(name):
            LOGGER.info("Skipping object gs://%s/%s", bucket, name)
            continue
        LOGGER.info("Processing gs://%s/%s", bucket, name)
        sent = 0
        event_count = 0
        batch: List[Dict[str, Any]] = []
        for event in iter_logpush_events(bucket, name):
            event_count += 1
            batch.append(event)
            if len(batch) >= CORALOGIX_BATCH_SIZE:
                sent += ship_to_coralogix(batch, source_bucket=bucket, source_key=name)
                batch = []
        if batch:
            sent += ship_to_coralogix(batch, source_bucket=bucket, source_key=name)
        total_events += event_count
        total_sent += sent
        processed.append(
            {"bucket": bucket, "name": name, "events": event_count, "sent": sent}
        )

    LOGGER.info("Done files=%s events=%s sent=%s", len(processed), total_events, total_sent)
    return {
        "ok": True,
        "files": len(processed),
        "events": total_events,
        "sent": total_sent,
        "processed": processed,
    }


def should_process(name: str) -> bool:
    if not name or name.endswith("/"):
        return False
    lower = name.lower()
    if KEY_SUFFIX and not lower.endswith(KEY_SUFFIX):
        return False
    if KEY_PREFIX and not name.startswith(KEY_PREFIX.lstrip("/")):
        return False
    return True


def extract_gcs_objects(
    data: Dict[str, Any],
    raw_event: Optional[Dict[str, Any]] = None,
) -> List[Tuple[str, str]]:
    """Pull bucket/name pairs from GCS finalize, Pub/Sub, or a manual payload."""
    found: List[Tuple[str, str]] = []
    raw_event = raw_event or {}

    bucket = (
        data.get("bucket")
        or data.get("bucketId")
        or raw_event.get("bucket")
    )
    name = (
        data.get("name")
        or data.get("objectId")
        or data.get("key")
        or raw_event.get("name")
        or raw_event.get("key")
    )
    if bucket and name:
        found.append((bucket, name))
        return found

    message = data.get("message") or {}
    attributes = message.get("attributes") or data.get("attributes") or {}
    bucket = attributes.get("bucketId") or attributes.get("bucket")
    name = attributes.get("objectId") or attributes.get("name")
    if bucket and name:
        found.append((bucket, name))
        return found

    encoded = message.get("data")
    if encoded:
        import base64

        try:
            decoded = base64.b64decode(encoded).decode("utf-8")
            nested = json.loads(decoded)
            if isinstance(nested, dict):
                return extract_gcs_objects(nested, nested)
        except (ValueError, json.JSONDecodeError, UnicodeDecodeError):
            LOGGER.warning("Pub/Sub message data was not JSON")

    proto = data.get("protoPayload") or {}
    resource = proto.get("resourceName") or ""
    # projects/_/buckets/<bucket>/objects/<name>
    if "/buckets/" in resource and "/objects/" in resource:
        after = resource.split("/buckets/", 1)[1]
        bucket, _, name = after.partition("/objects/")
        if bucket and name:
            found.append((bucket, name))

    return found


def iter_logpush_events(bucket: str, name: str) -> Iterator[Dict[str, Any]]:
    blob = _storage().bucket(bucket).blob(name)
    raw = blob.download_as_bytes()
    LOGGER.info("Downloaded gs://%s/%s bytes=%s", bucket, name, len(raw))
    text = _decode_object(raw, name)
    for line_no, line in enumerate(text.splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        event = _line_to_event(line, bucket=bucket, name=name, line_no=line_no)
        if event is not None:
            yield event


def _decode_object(raw: bytes, name: str) -> str:
    lower = name.lower()
    gzipped = lower.endswith(".gz") or lower.endswith(".gzip") or raw[:2] == b"\x1f\x8b"
    if gzipped:
        try:
            raw = gzip.decompress(raw)
        except OSError:
            LOGGER.warning("Object %s looked gzipped but decompress failed; treating as plain text", name)
    return raw.decode("utf-8", errors="replace")


def _line_to_event(
    line: str,
    *,
    bucket: str,
    name: str,
    line_no: int,
) -> Optional[Dict[str, Any]]:
    try:
        parsed = json.loads(line)
    except json.JSONDecodeError:
        LOGGER.warning("Skipping non-JSON line %s in gs://%s/%s", line_no, bucket, name)
        return None

    if isinstance(parsed, dict):
        event = parsed
    else:
        event = {"message": parsed}

    ts_ms = (
        _timestamp_ms(event.get("EdgeStartTimestamp"))
        or _timestamp_ms(event.get("Datetime"))
        or _timestamp_ms(event.get("datetime"))
        or _timestamp_ms(event.get("Timestamp"))
        or _timestamp_ms(event.get("timestamp"))
        or _timestamp_ms(event.get("EventTimestampMs"))
        or _timestamp_ms(event.get("WhenLogged"))
    )
    if ts_ms:
        event["_cx_timestamp"] = ts_ms

    if INCLUDE_SOURCE_METADATA:
        event.setdefault("cx_source", "cloudflare-gcs")
        event.setdefault("gcs_bucket", bucket)
        event.setdefault("gcs_object", name)
    return event


def _timestamp_ms(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        if value > 1_000_000_000_000_000:  # nanoseconds
            return int(value / 1_000_000)
        if value > 10_000_000_000:  # milliseconds
            return int(value)
        return int(value * 1000)
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return int(value.timestamp() * 1000)
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        if text.isdigit():
            return _timestamp_ms(int(text))
        try:
            if text.endswith("Z"):
                text = text[:-1] + "+00:00"
            return int(datetime.fromisoformat(text).timestamp() * 1000)
        except ValueError:
            return None
    return None


def map_severity(event: Dict[str, Any]) -> int:
    """Coralogix: 1 Debug through 6 Critical."""
    action = str(
        event.get("Action")
        or event.get("FirewallMatchesActions")
        or event.get("WAFAction")
        or ""
    ).lower()
    if any(
        token in action
        for token in ("block", "drop", "connectionterminate", "connection_terminate")
    ):
        return 5
    if "challenge" in action or "js_challenge" in action:
        return 4

    status = event.get("EdgeResponseStatus") or event.get("OriginResponseStatus") or event.get("ClientRequestStatus")
    try:
        status_int = int(status)
    except (TypeError, ValueError):
        status_int = 0
    if status_int >= 500:
        return 5
    if status_int >= 400:
        return 4
    return 3


def ship_to_coralogix(
    events: List[Dict[str, Any]],
    *,
    source_bucket: str,
    source_key: str,
) -> int:
    if not events:
        return 0
    if DRY_RUN:
        LOGGER.info(
            "DRY_RUN: would send %s events from gs://%s/%s",
            len(events),
            source_bucket,
            source_key,
        )
        return 0

    url = _coralogix_url()
    key = _api_key()
    application = _application()
    subsystem = _subsystem()
    sent = 0

    for batch in _chunks(events, CORALOGIX_BATCH_SIZE):
        log_entries = []
        for event in batch:
            ts = event.pop("_cx_timestamp", None) or utc_now_ms()
            log_entries.append(
                {
                    "timestamp": ts,
                    "severity": map_severity(event),
                    "text": json.dumps(event, separators=(",", ":"), default=str),
                }
            )
        body = {
            "applicationName": application,
            "subsystemName": subsystem,
            "logEntries": log_entries,
        }
        _post_with_retry(url, key, body)
        sent += len(log_entries)
        LOGGER.info("Shipped %s logs to Coralogix", len(log_entries))
    return sent


def _post_with_retry(url: str, api_key: str, body: Dict[str, Any]) -> None:
    payload = json.dumps(body).encode("utf-8")
    last_error: Optional[Exception] = None
    for attempt in range(1, MAX_RETRIES + 1):
        req = urllib.request.Request(
            url,
            data=payload,
            method="POST",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=CORALOGIX_TIMEOUT_SECONDS) as resp:
                if 200 <= resp.status < 300:
                    return
                raise RuntimeError(f"Coralogix ingest HTTP {resp.status}")
        except urllib.error.HTTPError as exc:
            last_error = exc
            detail = exc.read()[:500]
            retryable = exc.code in {429, 500, 502, 503, 504}
            LOGGER.warning(
                "Coralogix HTTP %s attempt %s/%s: %s",
                exc.code,
                attempt,
                MAX_RETRIES,
                detail,
            )
            if not retryable or attempt == MAX_RETRIES:
                raise RuntimeError(f"Coralogix ingest error {exc.code}: {detail!r}") from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = exc
            LOGGER.warning("Coralogix network error attempt %s/%s: %s", attempt, MAX_RETRIES, exc)
            if attempt == MAX_RETRIES:
                raise
        time.sleep(min(2 ** attempt, 16))
    raise RuntimeError(f"Coralogix ingest failed: {last_error}")


def _chunks(items: List[Dict[str, Any]], size: int) -> Iterable[List[Dict[str, Any]]]:
    size = max(1, size)
    for i in range(0, len(items), size):
        yield items[i : i + size]


def utc_now_ms() -> int:
    return int(time.time() * 1000)

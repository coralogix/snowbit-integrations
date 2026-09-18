"""
S3 Teleport parquet audit files ? Coralogix Logs API.

Triggered by S3 ObjectCreated (or SQS/SNS wrapping the same notification).
Reads Snappy-compressed Parquet written by Teleport Athena / External Audit
Storage, then POSTs each audit event to Coralogix.

Teleport parquet columns:
  uid, session_id, event_type, user, event_time, event_data
event_data is a JSON string of the full audit event.
"""

from __future__ import annotations

import io
import json
import logging
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

import boto3
import pyarrow as pa
import pyarrow.parquet as pq

LOGGER = logging.getLogger()
LOGGER.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())

s3 = boto3.client("s3")

CORALOGIX_BATCH_SIZE = int(os.getenv("CORALOGIX_BATCH_SIZE", "400"))
CORALOGIX_TIMEOUT_SECONDS = float(os.getenv("CORALOGIX_TIMEOUT_SECONDS", "60"))
MAX_RETRIES = int(os.getenv("CORALOGIX_MAX_RETRIES", "4"))
KEY_PREFIX = os.getenv("S3_KEY_PREFIX", "").strip()
KEY_SUFFIX = os.getenv("S3_KEY_SUFFIX", ".parquet").lower()
DRY_RUN = os.getenv("DRY_RUN", "").strip().lower() in {"1", "true", "yes"}


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
    return os.getenv("CORALOGIX_APPLICATION_NAME", os.getenv("CORALOGIX_APPLICATION", "teleport"))


def _subsystem() -> str:
    return os.getenv("CORALOGIX_SUBSYSTEM_NAME", os.getenv("CORALOGIX_SUBSYSTEM", "audit"))


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    objects = extract_s3_objects(event)
    if not objects:
        LOGGER.info("No S3 objects in event")
        return {"ok": True, "files": 0, "events": 0, "sent": 0}

    total_events = 0
    total_sent = 0
    processed = []

    for bucket, key in objects:
        if not should_process(key):
            LOGGER.info("Skipping key %s", key)
            continue
        LOGGER.info("Processing s3://%s/%s", bucket, key)
        rows = read_parquet_events(bucket, key)
        total_events += len(rows)
        sent = ship_to_coralogix(rows, source_bucket=bucket, source_key=key)
        total_sent += sent
        processed.append({"bucket": bucket, "key": key, "events": len(rows), "sent": sent})

    LOGGER.info("Done files=%s events=%s sent=%s", len(processed), total_events, total_sent)
    return {"ok": True, "files": len(processed), "events": total_events, "sent": total_sent, "processed": processed}


def should_process(key: str) -> bool:
    lower = key.lower()
    if KEY_SUFFIX and not lower.endswith(KEY_SUFFIX):
        return False
    if KEY_PREFIX and not key.startswith(KEY_PREFIX.lstrip("/")):
        return False
    if "/sessions/" in lower:
        return False
    return True


def extract_s3_objects(event: Dict[str, Any]) -> List[Tuple[str, str]]:
    """Pull bucket/key pairs from S3, SNS, or SQS notification shapes."""
    found: List[Tuple[str, str]] = []

    if "Records" not in event:
        bucket = event.get("bucket") or event.get("s3Bucket")
        key = event.get("key") or event.get("s3Key")
        if bucket and key:
            found.append((bucket, urllib.parse.unquote_plus(key)))
        return found

    for record in event["Records"]:
        if record.get("s3"):
            found.extend(_from_s3_record(record))
            continue

        sns_msg = (record.get("Sns") or {}).get("Message")
        if sns_msg:
            try:
                found.extend(extract_s3_objects(json.loads(sns_msg)))
            except json.JSONDecodeError:
                LOGGER.warning("SNS message was not JSON")
            continue

        body = record.get("body")
        if body:
            try:
                found.extend(extract_s3_objects(json.loads(body)))
            except json.JSONDecodeError:
                LOGGER.warning("SQS body was not JSON")

    return found


def _from_s3_record(record: Dict[str, Any]) -> List[Tuple[str, str]]:
    s3_info = record.get("s3") or {}
    bucket = (s3_info.get("bucket") or {}).get("name")
    key = (s3_info.get("object") or {}).get("key")
    if not bucket or not key:
        return []
    return [(bucket, urllib.parse.unquote_plus(key))]


def read_parquet_events(bucket: str, key: str) -> List[Dict[str, Any]]:
    response = s3.get_object(Bucket=bucket, Key=key)
    payload = response["Body"].read()
    table = pq.read_table(io.BytesIO(payload))
    LOGGER.info("Parquet schema=%s rows=%s", table.schema, table.num_rows)
    return [_row_to_event(row) for row in _iter_table_rows(table)]


def _iter_table_rows(table: pa.Table) -> Iterable[Dict[str, Any]]:
    columns = table.column_names
    for batch in table.to_batches(max_chunksize=2048):
        pylist = batch.to_pydict()
        n = batch.num_rows
        for i in range(n):
            yield {name: pylist[name][i] for name in columns}


def _row_to_event(row: Dict[str, Any]) -> Dict[str, Any]:
    raw = row.get("event_data")
    event: Dict[str, Any] = {}

    if isinstance(raw, (bytes, bytearray, memoryview)):
        raw = bytes(raw).decode("utf-8", errors="replace")
    if isinstance(raw, str) and raw.strip():
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                event = parsed
            else:
                event = {"event_data": parsed}
        except json.JSONDecodeError:
            event = {"event_data": raw}
    elif isinstance(raw, dict):
        event = dict(raw)

    def put_if_missing(field: str, value: Any) -> None:
        if value is None or value == "":
            return
        if field not in event or event[field] in (None, ""):
            event[field] = _jsonish(value)

    put_if_missing("uid", row.get("uid"))
    put_if_missing("sid", row.get("session_id"))
    put_if_missing("event", row.get("event_type"))
    put_if_missing("user", row.get("user"))

    ts_ms = _timestamp_ms(row.get("event_time")) or _timestamp_ms(event.get("time"))
    if ts_ms:
        event["_cx_timestamp"] = ts_ms

    event.setdefault("cx_source", "teleport-s3-parquet")
    return event


def _jsonish(value: Any) -> Any:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    if hasattr(value, "as_py"):
        return _jsonish(value.as_py())
    return value


def _timestamp_ms(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        # seconds vs milliseconds
        if value > 10_000_000_000:
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
        try:
            if text.endswith("Z"):
                text = text[:-1] + "+00:00"
            return int(datetime.fromisoformat(text).timestamp() * 1000)
        except ValueError:
            return None
    return None


def map_severity(event: Dict[str, Any]) -> int:
    """Coralogix: 1 Debug … 6 Critical."""
    code = str(event.get("code") or "")
    if code.endswith("E") or event.get("success") is False or event.get("error"):
        return 5
    if code.endswith("W"):
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
        LOGGER.info("DRY_RUN: would send %s events from s3://%s/%s", len(events), source_bucket, source_key)
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

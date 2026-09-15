#!/usr/bin/env python3
"""
Zendesk Support API → Coralogix Logs API.

Pulls account audit logs from:
  GET https://{subdomain}.zendesk.com/api/v2/audit_logs
and ships them to:
  POST https://ingress.<domain>/logs/v1/singles

Default cadence: last 5 minutes, every 5 minutes.

Usage:
  cp .env.example .env
  pip install -r requirements.txt
  python ship_zendesk_to_coralogix.py --once --lookback-minutes 5   # cron
  python ship_zendesk_to_coralogix.py                               # loop

Requires Zendesk Enterprise (or above) and an admin OAuth client
(client credentials grant). API tokens are deprecated by Zendesk
and stop working on April 30, 2027.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple, Union
from urllib.parse import urlparse

import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

LOGGER = logging.getLogger("zendesk-coralogix")

PAGE_SIZE = 100
SEEN_ID_LIMIT = 2000
OVERLAP_SECONDS = 2
DEFAULT_OAUTH_SCOPE = "auditlogs:read"
TOKEN_REFRESH_SKEW_SECONDS = 60

# Coralogix severity: 1 Debug … 6 Critical
ACTION_SEVERITY = {
    "create": 3,
    "update": 3,
    "login": 3,
    "exported": 4,
    "destroy": 4,
}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def utc_now_ms() -> int:
    return int(utc_now().timestamp() * 1000)


def parse_iso_to_ms(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value * 1000) if value < 10_000_000_000 else int(value)
    if not isinstance(value, str) or not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        return int(datetime.fromisoformat(text).timestamp() * 1000)
    except ValueError:
        return None


def ms_to_iso(ms: int) -> str:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def map_severity(event: Dict[str, Any]) -> int:
    action = str(event.get("action") or "").strip().lower()
    if action in ACTION_SEVERITY:
        return ACTION_SEVERITY[action]
    return 3


def env_csv(name: str, default: Optional[List[str]] = None) -> List[str]:
    raw = os.getenv(name, "").strip()
    if not raw:
        return list(default or [])
    return [part.strip() for part in raw.split(",") if part.strip()]


PLACEHOLDER_EMAILS = {
    "admin@example.com",
    "your-email@example.com",
    "you@example.com",
}


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def is_placeholder_email(value: Optional[str]) -> bool:
    if not value or not value.strip():
        return True
    email = value.strip().lower()
    return email in PLACEHOLDER_EMAILS or email.endswith("@example.com")


def zendesk_base_url() -> str:
    explicit = os.getenv("ZENDESK_BASE_URL", "").strip().rstrip("/")
    if explicit:
        return explicit
    subdomain = require_env("ZENDESK_SUBDOMAIN").strip()
    domain = os.getenv("ZENDESK_DOMAIN", "zendesk.com").strip().lstrip(".")
    host = subdomain.lower().rstrip("/")

    if host.startswith("http://") or host.startswith("https://"):
        return subdomain.rstrip("/")
    if host.endswith(".zendesk.com") or host.endswith(".zendesk.eu") or host.endswith(".zendesk.com.au"):
        return f"https://{subdomain}"
    if host in {"zendesk.com", "zendesk.eu", "zendesk.com.au"}:
        raise SystemExit(
            "ZENDESK_SUBDOMAIN should be the account name only, "
            "e.g. 'acme' for https://acme.zendesk.com — not 'zendesk.com'."
        )
    return f"https://{subdomain}.{domain}"


class StateStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.data: Dict[str, Any] = {
            "audit": {"seen_ids": [], "last_time_ms": None},
        }
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            return
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                self.data.update(loaded)
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("Could not load state file %s: %s", self.path, exc)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        tmp.write_text(json.dumps(self.data, indent=2, sort_keys=True), encoding="utf-8")
        tmp.replace(self.path)

    def get_seen_ids(self) -> Set[str]:
        audit = self.data.get("audit") or {}
        return {str(x) for x in (audit.get("seen_ids") or [])}

    def get_last_time_ms(self) -> Optional[int]:
        audit = self.data.get("audit") or {}
        value = audit.get("last_time_ms")
        return int(value) if value is not None else None

    def update(self, event_ids: Iterable[str], last_time_ms: Optional[int]) -> None:
        audit = self.data.setdefault("audit", {})
        merged = list(dict.fromkeys(list(event_ids) + list(audit.get("seen_ids") or [])))
        audit["seen_ids"] = merged[:SEEN_ID_LIMIT]
        if last_time_ms is not None:
            prev = audit.get("last_time_ms")
            audit["last_time_ms"] = (
                max(int(prev), last_time_ms) if prev is not None else last_time_ms
            )


class ZendeskClient:
    def __init__(
        self,
        base_url: str,
        *,
        client_id: Optional[str] = None,
        client_secret: Optional[str] = None,
        oauth_scope: str = DEFAULT_OAUTH_SCOPE,
        oauth_token: Optional[str] = None,
        email: Optional[str] = None,
        api_token: Optional[str] = None,
        timeout: float = 60.0,
        page_delay_seconds: float = 0.0,
        session: Optional[requests.Session] = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.page_delay_seconds = max(0.0, page_delay_seconds)
        self.session = session or requests.Session()
        self.headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        self.auth: Optional[HTTPBasicAuth] = None
        self.client_id = (client_id or "").strip()
        self.client_secret = (client_secret or "").strip()
        self.oauth_scope = (oauth_scope or "").strip() or DEFAULT_OAUTH_SCOPE
        self._token_expires_at: Optional[float] = None

        static_oauth = (oauth_token or "").strip()
        email = "" if is_placeholder_email(email) else (email or "").strip()
        api_token = (api_token or "").strip()

        if self.client_id and self.client_secret:
            self._fetch_client_credentials_token()
        elif self.client_id or self.client_secret:
            raise SystemExit(
                "OAuth client credentials require both ZENDESK_CLIENT_ID and "
                "ZENDESK_CLIENT_SECRET."
            )
        elif static_oauth:
            self.headers["Authorization"] = f"Bearer {static_oauth}"
        elif email and api_token:
            LOGGER.warning(
                "ZENDESK_EMAIL + ZENDESK_API_TOKEN is deprecated. Zendesk disables "
                "API tokens on April 30, 2027. Switch to ZENDESK_CLIENT_ID + "
                "ZENDESK_CLIENT_SECRET (OAuth client credentials)."
            )
            self.auth = HTTPBasicAuth(f"{email}/token", api_token)
        else:
            raise SystemExit(
                "Zendesk authentication required. Set ZENDESK_CLIENT_ID and "
                "ZENDESK_CLIENT_SECRET (OAuth client credentials). API tokens "
                "are deprecated and stop working on April 30, 2027."
            )

    def _can_refresh_oauth_token(self) -> bool:
        return bool(self.client_id and self.client_secret)

    def _oauth_token_needs_refresh(self) -> bool:
        if not self._can_refresh_oauth_token():
            return False
        if "Authorization" not in self.headers:
            return True
        if self._token_expires_at is None:
            return False
        return time.monotonic() >= self._token_expires_at

    def _fetch_client_credentials_token(self) -> None:
        url = f"{self.base_url}/oauth/tokens"
        payload = {
            "grant_type": "client_credentials",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "scope": self.oauth_scope,
        }
        try:
            resp = self.session.post(
                url,
                data=payload,
                headers={"Accept": "application/json"},
                timeout=self.timeout,
            )
        except requests.RequestException as exc:
            raise RuntimeError(f"Failed to request Zendesk OAuth token: {exc}") from exc

        if resp.status_code == 401:
            raise RuntimeError(
                "Zendesk rejected the OAuth client credentials (401). "
                "Check ZENDESK_CLIENT_ID and ZENDESK_CLIENT_SECRET."
            )
        if resp.status_code == 400 and "invalid_scope" in (resp.text or ""):
            raise RuntimeError(
                "Zendesk rejected the OAuth scope. Set the client's allowed "
                f"scopes to include {self.oauth_scope}, or set ZENDESK_OAUTH_SCOPE. "
                f"Response: {resp.text[:500]}"
            )
        if not resp.ok:
            raise RuntimeError(
                f"Zendesk OAuth token error {resp.status_code}: {resp.text[:500]}"
            )

        try:
            data = resp.json() if resp.content else {}
        except ValueError as exc:
            raise RuntimeError("Zendesk OAuth token response was not JSON") from exc

        access_token = (data.get("access_token") or "").strip()
        if not access_token:
            raise RuntimeError("Zendesk OAuth response did not include access_token")

        self.headers["Authorization"] = f"Bearer {access_token}"
        expires_in = data.get("expires_in")
        if expires_in:
            self._token_expires_at = (
                time.monotonic() + float(expires_in) - TOKEN_REFRESH_SKEW_SECONDS
            )
        else:
            self._token_expires_at = None
        LOGGER.debug(
            "Obtained Zendesk OAuth access token (scope=%s expires_in=%s)",
            data.get("scope") or self.oauth_scope,
            expires_in,
        )

    def _request(
        self,
        method: str,
        url: str,
        *,
        params: Optional[Union[Dict[str, Any], List[Tuple[str, Any]]]] = None,
        max_retries: int = 6,
    ) -> Dict[str, Any]:
        last_error: Optional[Exception] = None
        refreshed_oauth = False
        for attempt in range(max_retries):
            if self._oauth_token_needs_refresh():
                self._fetch_client_credentials_token()
            try:
                resp = self.session.request(
                    method,
                    url,
                    headers=self.headers,
                    auth=self.auth,
                    params=params,
                    timeout=self.timeout,
                )
            except requests.RequestException as exc:
                last_error = exc
                sleep_for = min(2**attempt, 30)
                LOGGER.warning("Request error (%s); retrying in %ss", exc, sleep_for)
                time.sleep(sleep_for)
                continue

            if resp.status_code == 401 and self._can_refresh_oauth_token() and not refreshed_oauth:
                LOGGER.info("Zendesk returned 401; refreshing OAuth access token")
                self._fetch_client_credentials_token()
                refreshed_oauth = True
                continue

            if resp.status_code == 429:
                retry_after = resp.headers.get("Retry-After")
                try:
                    sleep_for = max(1, int(float(retry_after))) if retry_after else min(2**attempt, 60)
                except ValueError:
                    sleep_for = min(2**attempt, 60)
                LOGGER.warning("Rate limited by Zendesk; sleeping %ss", sleep_for)
                time.sleep(sleep_for)
                continue

            if resp.status_code >= 500:
                sleep_for = min(2**attempt, 30)
                LOGGER.warning(
                    "Zendesk %s on %s; retrying in %ss",
                    resp.status_code,
                    url,
                    sleep_for,
                )
                time.sleep(sleep_for)
                continue

            if resp.status_code == 403:
                raise RuntimeError(
                    "Zendesk returned 403 Forbidden. Audit logs require an Enterprise "
                    "plan and an admin associated with the OAuth client (or a token "
                    f"with auditlogs:read). Response: {resp.text[:500]}"
                )

            if resp.status_code == 404:
                raise RuntimeError(
                    "Zendesk returned 404 for audit logs. Check ZENDESK_SUBDOMAIN / "
                    f"ZENDESK_BASE_URL. Response: {resp.text[:500]}"
                )

            if not resp.ok:
                raise RuntimeError(
                    f"Zendesk API error {resp.status_code} for {url}: {resp.text[:500]}"
                )

            if not resp.content:
                return {}
            return resp.json()

        raise RuntimeError(f"Zendesk API failed after retries for {url}: {last_error}")

    def fetch_audit_logs(
        self,
        *,
        start_ms: int,
        end_ms: int,
        seen_ids: Set[str],
        actions: Optional[List[str]] = None,
        source_types: Optional[List[str]] = None,
        max_pages: int = 500,
    ) -> List[Dict[str, Any]]:
        params: List[Tuple[str, Any]] = [
            ("page[size]", PAGE_SIZE),
            ("sort", "created_at"),
            ("filter[created_at][]", ms_to_iso(start_ms)),
            ("filter[created_at][]", ms_to_iso(end_ms)),
        ]
        for action in actions or []:
            params.append(("filter[action][]", action))
        for source_type in source_types or []:
            params.append(("filter[source_type][]", source_type))

        url: Optional[str] = f"{self.base_url}/api/v2/audit_logs"
        events: List[Dict[str, Any]] = []
        pages = 0
        scanned = 0

        while url and pages < max_pages:
            payload = self._request("GET", url, params=params if pages == 0 else None)
            page_logs = payload.get("audit_logs") or []
            pages += 1
            scanned += len(page_logs)

            for event in page_logs:
                event_id = str(event.get("id") or "")
                if event_id and event_id in seen_ids:
                    continue
                events.append(event)

            meta = payload.get("meta") or {}
            links = payload.get("links") or {}
            next_url = links.get("next") or payload.get("next_page")
            if not next_url or meta.get("has_more") is False:
                url = None
            else:
                url = next_url
                if self.page_delay_seconds:
                    time.sleep(self.page_delay_seconds)

        LOGGER.info(
            "Zendesk audit scan: pages=%s scanned=%s kept=%s window=%s .. %s",
            pages,
            scanned,
            len(events),
            ms_to_iso(start_ms),
            ms_to_iso(end_ms),
        )
        if pages >= max_pages:
            LOGGER.warning("Stopped after max_pages=%s; more audit logs may remain", max_pages)
        return events


class CoralogixShipper:
    def __init__(
        self,
        api_key: str,
        domain: str,
        application_name: str,
        subsystem_name: str,
        batch_size: int = 200,
        timeout: float = 60.0,
        session: Optional[requests.Session] = None,
    ) -> None:
        domain = domain.lstrip(".").strip()
        self.url = f"https://ingress.{domain}/logs/v1/singles"
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        self.application_name = application_name
        self.subsystem_name = subsystem_name
        self.batch_size = max(1, batch_size)
        self.timeout = timeout
        self.session = session or requests.Session()

    def _to_cx_record(self, event: Dict[str, Any]) -> Dict[str, Any]:
        ts = parse_iso_to_ms(event.get("created_at")) or utc_now_ms()
        actor = event.get("actor_name") or event.get("ip_address")
        record: Dict[str, Any] = {
            "applicationName": self.application_name,
            "subsystemName": self.subsystem_name,
            "severity": map_severity(event),
            "category": "zendesk-audit",
            "timestamp": ts,
            "text": json.dumps(event, separators=(",", ":"), default=str),
        }
        if actor:
            record["computerName"] = str(actor)
        return record

    def ship(self, events: Iterable[Dict[str, Any]]) -> int:
        batch: List[Dict[str, Any]] = []
        sent = 0

        def flush() -> None:
            nonlocal sent, batch
            if not batch:
                return
            resp = self.session.post(
                self.url,
                headers=self.headers,
                data=json.dumps(batch, separators=(",", ":")),
                timeout=self.timeout,
            )
            if not resp.ok:
                raise RuntimeError(
                    f"Coralogix ingest error {resp.status_code}: {resp.text[:500]}"
                )
            sent += len(batch)
            LOGGER.info("Shipped %s logs to Coralogix (zendesk-audit)", len(batch))
            batch = []

        for event in events:
            enriched = dict(event)
            enriched.setdefault("cx_source", "zendesk")
            enriched.setdefault("cx_category", "audit")
            batch.append(self._to_cx_record(enriched))
            if len(batch) >= self.batch_size:
                flush()
        flush()
        return sent


def poll_audit(
    zendesk: ZendeskClient,
    shipper: CoralogixShipper,
    state: StateStore,
    lookback_minutes: int,
    *,
    dry_run: bool = False,
) -> int:
    seen_ids = state.get_seen_ids()
    last_time_ms = state.get_last_time_ms()
    now_ms = utc_now_ms()
    lookback_ms = lookback_minutes * 60 * 1000
    window_start = now_ms - lookback_ms
    overlap_ms = OVERLAP_SECONDS * 1000

    # Each cycle polls the last LOOKBACK_MINUTES. If cron was delayed, catch up
    # from the last checkpoint so events are not dropped.
    if last_time_ms is not None and last_time_ms < window_start:
        start_ms = max(0, last_time_ms - overlap_ms)
        LOGGER.info("Catching up from last checkpoint (gap larger than lookback window)")
    else:
        start_ms = max(0, window_start - overlap_ms)

    events = zendesk.fetch_audit_logs(
        start_ms=start_ms,
        end_ms=now_ms,
        seen_ids=seen_ids,
        actions=env_csv("ZENDESK_FILTER_ACTIONS"),
        source_types=env_csv("ZENDESK_FILTER_SOURCE_TYPES"),
    )
    if not events:
        LOGGER.info("Audit: no new events")
        return 0

    new_ids: List[str] = []
    max_ts: Optional[int] = last_time_ms
    for event in events:
        event["event_source"] = "zendesk_audit"
        event_id = str(event.get("id") or "")
        if event_id:
            new_ids.append(event_id)
        event_ts = parse_iso_to_ms(event.get("created_at"))
        if event_ts is not None:
            max_ts = event_ts if max_ts is None else max(max_ts, event_ts)

    if dry_run:
        LOGGER.info("Dry run: would ship %s events (not sending, not saving state)", len(events))
        for event in events[:5]:
            LOGGER.info(
                "Sample: id=%s action=%s actor=%s source=%s created_at=%s",
                event.get("id"),
                event.get("action"),
                event.get("actor_name"),
                event.get("source_type"),
                event.get("created_at"),
            )
        return 0

    sent = shipper.ship(events)
    state.update(new_ids, max_ts)
    state.save()
    LOGGER.info("Audit: shipped %s events", sent)
    return sent


def resolve_lookback_minutes(args: argparse.Namespace) -> int:
    if getattr(args, "lookback_minutes", None) is not None:
        return int(args.lookback_minutes)
    if getattr(args, "lookback_hours", None) is not None:
        return int(args.lookback_hours) * 60
    if os.getenv("LOOKBACK_MINUTES"):
        return int(os.getenv("LOOKBACK_MINUTES", "5"))
    if os.getenv("LOOKBACK_HOURS"):
        return int(os.getenv("LOOKBACK_HOURS", "1")) * 60
    return 5


def run_once(args: argparse.Namespace) -> int:
    zendesk = ZendeskClient(
        base_url=zendesk_base_url(),
        client_id=os.getenv("ZENDESK_CLIENT_ID", "").strip() or None,
        client_secret=os.getenv("ZENDESK_CLIENT_SECRET", "").strip() or None,
        oauth_scope=os.getenv("ZENDESK_OAUTH_SCOPE", DEFAULT_OAUTH_SCOPE).strip()
        or DEFAULT_OAUTH_SCOPE,
        oauth_token=os.getenv("ZENDESK_OAUTH_TOKEN", "").strip() or None,
        email=os.getenv("ZENDESK_EMAIL", "").strip() or None,
        api_token=os.getenv("ZENDESK_API_TOKEN", "").strip() or None,
        timeout=float(os.getenv("HTTP_TIMEOUT_SECONDS", "60")),
        page_delay_seconds=float(os.getenv("ZENDESK_PAGE_DELAY_SECONDS", "0")),
    )
    shipper = CoralogixShipper(
        api_key=(
            os.getenv("CORALOGIX_SEND_YOUR_DATA_KEY", "").strip()
            if args.dry_run
            else require_env("CORALOGIX_SEND_YOUR_DATA_KEY")
        )
        or "dry-run",
        domain=os.getenv("CORALOGIX_DOMAIN", "coralogix.com").strip(),
        application_name=os.getenv("CORALOGIX_APPLICATION_NAME", "zendesk"),
        subsystem_name=os.getenv("CORALOGIX_SUBSYSTEM_NAME", "audit-logs"),
        batch_size=int(os.getenv("CORALOGIX_BATCH_SIZE", "200")),
        timeout=float(os.getenv("HTTP_TIMEOUT_SECONDS", "60")),
    )
    state = StateStore(Path(os.getenv("STATE_FILE", "./state.json")))
    lookback_minutes = resolve_lookback_minutes(args)
    LOGGER.info(
        "Polling %s lookback=%s minute(s) dry_run=%s",
        urlparse(zendesk.base_url).netloc,
        lookback_minutes,
        args.dry_run,
    )
    return poll_audit(
        zendesk,
        shipper,
        state,
        lookback_minutes,
        dry_run=args.dry_run,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Poll Zendesk audit logs and ship them to Coralogix"
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run a single poll cycle and exit (recommended for cron)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch Zendesk logs but do not send to Coralogix or update state",
    )
    parser.add_argument(
        "--lookback-minutes",
        type=int,
        default=None,
        help="Lookback window in minutes (default: 5)",
    )
    parser.add_argument(
        "--lookback-hours",
        type=int,
        default=None,
        help="Lookback window in hours (alternative to --lookback-minutes)",
    )
    parser.add_argument(
        "--log-level",
        default=os.getenv("LOG_LEVEL", "INFO"),
        help="Logging level (default: INFO)",
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    load_dotenv()
    parser = build_parser()
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    if args.once or args.dry_run:
        sent = run_once(args)
        LOGGER.info("Done. Total events shipped: %s", sent)
        return 0

    interval = int(os.getenv("POLL_INTERVAL_SECONDS", "300"))
    LOGGER.info("Starting continuous poller (interval=%ss)", interval)
    while True:
        cycle_start = time.time()
        try:
            sent = run_once(args)
            LOGGER.info("Cycle complete. Shipped %s events", sent)
        except Exception:
            LOGGER.exception("Poll cycle failed")
        elapsed = time.time() - cycle_start
        sleep_for = max(1.0, interval - elapsed)
        time.sleep(sleep_for)


if __name__ == "__main__":
    sys.exit(main())

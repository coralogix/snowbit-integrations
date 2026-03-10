#!/usr/bin/env python3
"""
Deploy unified Linux log parser to Coralogix (otelcol-contrib / OTEL format).

Single rule group with AND/OR logic. Output includes:
- raw_log: original log content
- log_file_name: from logRecord.attributes (e.g. ufw.log, auth.log)
- timestamp, hostname, tag, message, pid (syslog/auth) or action, details (dpkg)
- src, dst, in, proto (UFW BLOCK messages)

Usage:
  export CORALOGIX_API_KEY="your-api-key"
  export CORALOGIX_ENDPOINT="eu1.coralogix.com"
  python deploy_linux_parsers.py [--delete-first] [--dry-run]
"""

import json
import os
import sys
import urllib.request
from pathlib import Path

# Add parent for app imports
sys.path.insert(0, str(Path(__file__).parent))

# Parser names we created (to delete on --delete-first)
PARSER_NAMES_TO_DELETE = [
    "OTEL JSON Body Extractor",
    "OTEL Linux UFW",
    "OTEL Linux Syslog (journald)",
    "Linux dpkg.log Parser",
    "OTEL Linux Logs (Unified)",
]


def get_api_config():
    """Get API key and endpoint from environment."""
    api_key = os.environ.get("CORALOGIX_API_KEY")
    endpoint = os.environ.get("CORALOGIX_ENDPOINT", "eu1.coralogix.com").strip()

    if endpoint.startswith("https://"):
        endpoint = endpoint.replace("https://", "")
    if endpoint.startswith("api."):
        endpoint = endpoint.replace("api.", "")

    return api_key, endpoint


def list_rule_groups(api_key: str, endpoint: str):
    """List all rule groups and return IDs of our parsers."""
    url = f"https://api.{endpoint}/mgmt/openapi/latest/parsing-rules/rule-groups/v1"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {api_key}",
        "User-Agent": "Coralogix-Parser-Deploy/1.0",
    }, method="GET")
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode())
    return data.get("ruleGroups", [])


def delete_rule_groups(api_key: str, endpoint: str, group_ids: list, dry_run: bool = False):
    """Delete rule groups by ID."""
    if not group_ids:
        return True
    if dry_run:
        print(f"  [DRY RUN] Would delete: {group_ids}")
        return True

    url = f"https://api.{endpoint}/mgmt/openapi/latest/parsing-rules/rule-groups/v1?group_ids=" + "&group_ids=".join(group_ids)
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {api_key}",
        "User-Agent": "Coralogix-Parser-Deploy/1.0",
    }, method="DELETE")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"  ✓ Deleted {len(group_ids)} rule group(s)")
            return True
    except urllib.error.HTTPError as e:
        print(f"  ✗ Delete failed: HTTP {e.code} - {e.read().decode()[:200]}")
        return False


def build_unified_rule_group():
    """
    Build a single rule group for all OTEL Linux logs.
    EXTRACT only - original log unchanged, adds new JSON keys.
    """
    # ISO syslog/journald: 2026-03-09T18:08:38.510893+05:30 asus kernel: message
    syslog_regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z)?)\s+(?P<hostname>\S+)\s+(?P<tag>\S+):\s*(?P<message>.*)$'
    # auth.log/secure/cron RFC 3164: Mar  9 10:15:32 hostname sshd[12345]: message
    auth_regex = r'^(?P<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<hostname>\S+)\s+(?P<tag>\S+?)(\[(?P<pid>\d+)\])?:\s*(?P<message>.*)$'
    # dpkg: 2025-03-09 10:15:32 status installed nginx
    dpkg_regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(?P<action>\S+)\s+(?P<details>.*)$'

    return {
        "name": "OTEL Linux Logs (Unified)",
        "description": "EXTRACT only - keeps original log intact, adds new JSON keys for syslog/auth/cron/dpkg/UFW.",
        "enabled": True,
        "ruleMatchers": [],
        "rulesGroups": [
            # Order 1: Extract body and log_file_name from OTEL JSON (text unchanged)
            {
                "order": 1,
                "rules": [
                    {"name": "Extract body", "enabled": True, "type": "extract", "sourceField": "text", "order": 1, "rule": r'"body"\s*:\s*"(?P<body>[^"]*)"'},
                    {"name": "Extract log_file_name", "enabled": True, "type": "extract", "sourceField": "text", "order": 2, "rule": r'"log\.file\.name"\s*:\s*"(?P<log_file_name>[^"]*)"'},
                ],
            },
            # Order 2: Extract syslog/auth/dpkg fields from text or body (adds timestamp, hostname, tag, pid, message)
            {
                "order": 2,
                "rules": [
                    {"name": "Extract syslog from text", "enabled": True, "type": "extract", "sourceField": "text", "order": 1, "rule": syslog_regex},
                    {"name": "Extract syslog from body", "enabled": True, "type": "extract", "sourceField": "body", "order": 2, "rule": syslog_regex},
                    {"name": "Extract auth/cron from text", "enabled": True, "type": "extract", "sourceField": "text", "order": 3, "rule": auth_regex},
                    {"name": "Extract auth/cron from body", "enabled": True, "type": "extract", "sourceField": "body", "order": 4, "rule": auth_regex},
                    {"name": "Extract dpkg from text", "enabled": True, "type": "extract", "sourceField": "text", "order": 5, "rule": dpkg_regex},
                    {"name": "Extract dpkg from body", "enabled": True, "type": "extract", "sourceField": "body", "order": 6, "rule": dpkg_regex},
                ],
            },
            # Order 3: Extract UFW fields from message
            {
                "order": 3,
                "rules": [
                    {"name": "Extract UFW fields", "enabled": True, "type": "extract", "sourceField": "message", "order": 1, "rule": r"IN=(?P<in>\S+).*?SRC=(?P<src>\d+\.\d+\.\d+\.\d+).*?DST=(?P<dst>\d+\.\d+\.\d+\.\d+).*?PROTO=(?P<proto>\d+)"},
                ],
            },
            # Order 4: Extract secure/auth and cron fields from message
            {
                "order": 4,
                "rules": [
                    {"name": "Extract user from session", "enabled": True, "type": "extract", "sourceField": "message", "order": 1, "rule": r"session (?:opened|closed) for user (?P<user>\S+)(?:\(uid=\d+\))?|Accepted (?:password|publickey) for (?P<user>\S+) from"},
                    {"name": "Extract src_ip", "enabled": True, "type": "extract", "sourceField": "message", "order": 2, "rule": r"(?:from|Received disconnect from)\s+(?P<src_ip>\d+\.\d+\.\d+\.\d+)"},
                    {"name": "Extract action", "enabled": True, "type": "extract", "sourceField": "message", "order": 3, "rule": r"(?P<action>opened|closed|disconnected|Accepted|Failed)"},
                    {"name": "Extract eventtype", "enabled": True, "type": "extract", "sourceField": "message", "order": 4, "rule": r"(?P<eventtype>pam_unix|sshd|runuser|sudo|su|login|polkit)(?:\([^)]+\))?:"},
                    {"name": "Extract dest from disconnect", "enabled": True, "type": "extract", "sourceField": "message", "order": 5, "rule": r"disconnect from (?P<dest>\d+\.\d+\.\d+\.\d+)"},
                    {"name": "Extract cron user", "enabled": True, "type": "extract", "sourceField": "message", "order": 6, "rule": r"\((?P<user>\w+)\)\s+CMD"},
                    {"name": "Extract cron_cmd", "enabled": True, "type": "extract", "sourceField": "message", "order": 7, "rule": r"CMD\s+\((?P<cron_cmd>[^)]+)\)"},
                ],
            },
        ],
    }


def build_rule_groups():
    """Return single unified rule group."""
    return [build_unified_rule_group()]


def deploy(api_key: str, endpoint: str, dry_run: bool = False):
    """Deploy parsers to Coralogix."""
    url = f"https://api.{endpoint}/api/v1/external/rule/rule-set"
    rule_groups = build_rule_groups()

    print(f"Deploying {len(rule_groups)} parser(s) to {url}")
    for i, rg in enumerate(rule_groups, 1):
        print(f"  {i}. {rg['name']}")

    if dry_run:
        print("\n[DRY RUN] Would POST:")
        for rg in rule_groups:
            print(json.dumps(rg, indent=2))
        return True

    success_count = 0
    errors = []

    for rg in rule_groups:
        try:
            data = json.dumps(rg).encode("utf-8")
            req = urllib.request.Request(
                url,
                data=data,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {api_key}",
                    "User-Agent": "Coralogix-Parser-Deploy/1.0",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                if resp.status in (200, 201):
                    print(f"  ✓ Deployed: {rg['name']}")
                    success_count += 1
                else:
                    errors.append(f"{rg['name']}: HTTP {resp.status}")
        except urllib.error.HTTPError as e:
            body = e.read().decode() if e.fp else ""
            errors.append(f"{rg['name']}: HTTP {e.code} - {body[:500]}")
        except Exception as e:
            errors.append(f"{rg['name']}: {e}")

    if errors:
        print("\nErrors:")
        for err in errors:
            print(f"  ✗ {err}")
        return False

    print(f"\nSuccessfully deployed {success_count} parser(s).")
    return True


def main():
    dry_run = "--dry-run" in sys.argv
    delete_first = "--delete-first" in sys.argv
    api_key, endpoint = get_api_config()

    if not api_key and not dry_run:
        print(
            "Error: CORALOGIX_API_KEY is required.\n"
            "  export CORALOGIX_API_KEY='your-api-key'\n"
            "  python deploy_linux_parsers.py [--delete-first]"
        )
        sys.exit(1)

    if not api_key:
        api_key = "dummy"
        endpoint = endpoint or "eu1.coralogix.com"

    if dry_run:
        print("Running in dry-run mode (no API calls).\n")

        # Step 1: Delete existing parsers
    if delete_first and api_key != "dummy":
        print("Deleting existing parsers...")
        groups = list_rule_groups(api_key, endpoint)
        ids_to_delete = [g["id"] for g in groups if g["name"] in PARSER_NAMES_TO_DELETE]
        if ids_to_delete:
            delete_rule_groups(api_key, endpoint, ids_to_delete, dry_run)
        else:
            print("  No matching parsers to delete.")
        print()

    # Step 2: Deploy new parsers
    ok = deploy(api_key, endpoint, dry_run=dry_run)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

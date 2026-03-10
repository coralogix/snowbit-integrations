#!/usr/bin/env python3
"""
Deploy parser via Coralogix Management API (cx498/coralogix.com format).
Converts legacy format to ruleSubgroups + parameters.
"""
import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path


# Fields that need text. prefix for Coralogix Management API
NEED_TEXT_PREFIX = {
    "body", "message", "hostname", "tag", "src_ip", "user", "timestamp",
    "level", "host", "pid", "source", "action", "eventtype", "dest", "cron_cmd",
    "dvc", "process", "app", "src", "user_name", "remote_addr", "request",
    "status", "time_local", "http_referer", "http_user_agent",
}


def fix_source_field(sf: str) -> str:
    """Ensure sourceField has text. prefix when required."""
    if sf in NEED_TEXT_PREFIX:
        return f"text.{sf}"
    if sf.startswith("text."):
        return sf
    return sf


def convert_to_mgmt_format(legacy: dict) -> dict:
    """Convert legacy rulesGroups format to Management API ruleSubgroups + parameters.
    Coralogix requires sourceField to use text. prefix for extracted fields.
    """
    mgmt = {
        "name": legacy["name"],
        "description": legacy.get("description", ""),
        "enabled": legacy.get("enabled", True),
        "ruleMatchers": legacy.get("ruleMatchers", []),
        "ruleSubgroups": [],
    }
    for sg in legacy.get("rulesGroups", []):
        rules = []
        for r in sg.get("rules", []):
            rule_type = r.get("type", "extract")
            params = {}
            if rule_type == "extract":
                params = {"extractParameters": {"rule": r["rule"]}}
            elif rule_type == "parse":
                params = {"parseParameters": {"destinationField": r.get("destinationField", "text"), "rule": r["rule"]}}
            elif rule_type == "replace":
                params = {"replaceParameters": {"destinationField": r.get("destinationField", "text"), "replaceNewVal": r.get("replaceNewVal", ""), "rule": r["rule"]}}
            elif rule_type == "timestampextract":
                params = {"extractTimestampParameters": {"format": r.get("timeFormat", ""), "standard": "FORMAT_STANDARD_STRFTIME_OR_UNSPECIFIED"}}
            elif rule_type == "jsonextract":
                params = {"jsonExtractParameters": {"destinationField": r.get("destinationField", "text"), "rule": r.get("rule", "")}}
            else:
                continue
            rules.append({
                "name": r["name"],
                "enabled": r.get("enabled", True),
                "order": r.get("order", 1),
                "sourceField": fix_source_field(r.get("sourceField", "text")),
                "parameters": params,
            })
        mgmt["ruleSubgroups"].append({"order": sg["order"], "enabled": True, "rules": rules})
    return mgmt


def deploy_from_dict(legacy: dict, api_key: str, endpoint: str) -> bool:
    """Deploy a rule group dict to Coralogix via Management API. Returns True on success."""
    endpoint = endpoint.strip().replace("https://", "").replace("http://", "").replace("api.", "")
    url = f"https://api.{endpoint}/mgmt/openapi/latest/parsing-rules/rule-groups/v1"
    payload = convert_to_mgmt_format(legacy)
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode()}")


def deploy(api_key: str, endpoint: str, rule_file: str) -> bool:
    endpoint = endpoint.strip().replace("https://", "").replace("http://", "").replace("api.", "")
    url = f"https://api.{endpoint}/mgmt/openapi/latest/parsing-rules/rule-groups/v1"

    legacy = json.loads(Path(rule_file).read_text())
    payload = convert_to_mgmt_format(legacy)

    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"✓ Deployed: {legacy['name']}")
            return True
    except urllib.error.HTTPError as e:
        print(f"✗ HTTP {e.code}: {e.read().decode()}")
        return False


if __name__ == "__main__":
    api_key = os.environ.get("CORALOGIX_API_KEY")
    endpoint = os.environ.get("CORALOGIX_ENDPOINT", "cx498.coralogix.com")
    rule_file = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).parent / "parsers/otel_linux_secure.json")

    if not api_key:
        print("Error: Set CORALOGIX_API_KEY")
        print("  export CORALOGIX_API_KEY='your-api-key'")
        sys.exit(1)

    ok = deploy(api_key, endpoint, rule_file)
    if not ok:
        print("\nIf you get 403: Ensure your API key has PARSINGRULES role (create/write).")
        print("Manual import: Coralogix → Data Flow → Parsing → Add Rule Group → paste rules from parsers/otel_linux_secure.json")
    sys.exit(0 if ok else 1)

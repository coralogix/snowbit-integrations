"""
Coralogix Parser Builder - Identify log sources, generate parsers, deploy to Coralogix.
Use in any Cursor project: python -m coralogix_parser identify/generate/deploy
"""
import json
import re
import urllib.request
import urllib.error
from pathlib import Path
DATA_DIR = Path(__file__).parent / "data"
LOG_SOURCES_FILE = DATA_DIR / "log_sources.json"


def load_log_sources():
    """Load log source definitions from JSON."""
    with open(LOG_SOURCES_FILE, "r") as f:
        data = json.load(f)
    return data["log_sources"]


def identify_log_source(log_sample: str, log_sources: list) -> list:
    """
    Identify log source(s) from sample log text.
    Returns list of matches with confidence scores.
    """
    log_sample = log_sample.strip()
    if not log_sample:
        return []

    matches = []
    for source in log_sources:
        score = 0
        matched_patterns = []
        for pattern in source["patterns"]:
            try:
                if re.search(pattern, log_sample, re.MULTILINE | re.DOTALL):
                    score += 1
                    matched_patterns.append(pattern)
            except re.error:
                continue

        if score > 0:
            confidence = min(100, (score / len(source["patterns"])) * 100 + 20)
            matches.append({
                "source": source,
                "confidence": round(confidence, 1),
                "matched_patterns": matched_patterns,
            })

    return sorted(matches, key=lambda x: x["confidence"], reverse=True)


def generate_nginx_access_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for NGINX access logs."""
    # Standard combined log format: IP - - [date] "request" status size "referer" "user-agent"
    regex = r'^(?P<remote_addr>\S+)\s+-\s+(?P<remote_user>\S+)\s+\[(?P<time_local>[^\]]+)\]\s+"(?P<request>[^"]*)"\s+(?P<status>\d+)\s+(?P<body_bytes_sent>\d+)\s+"(?P<http_referer>[^"]*)"\s+"(?P<http_user_agent>[^"]*)"'

    return {
        "rule_group": {
            "name": "NGINX Access Log Parser",
            "description": "Parses NGINX combined/access log format into structured fields",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse NGINX Access Log",
                            "description": "Extract remote_addr, request, status, and other fields",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp from time_local",
                            "description": "Parse NGINX date format to Coralogix timestamp",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.time_local",
                            "order": 1,
                            "timeFormat": "%d/%b/%Y:%H:%M:%S %z",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule",
                "description": "Add a PARSE rule to extract structured fields from the NGINX access log.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["remote_addr", "remote_user", "time_local", "request", "status", "body_bytes_sent", "http_referer", "http_user_agent"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT Rule",
                "description": "Extract the timestamp from time_local field (format: 05/Mar/2025:10:15:32 +0000) to use as log timestamp.",
                "rule_type": "timestampextract",
                "source_field": "text.time_local",
                "time_format": "%d/%b/%Y:%H:%M:%S %z",
            },
        ],
    }


def generate_heroku_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Heroku router logs."""
    regex = r'^(sock=)?(?P<sock>\S*)\s*at=(?P<severity>\S*)\s*code=(?P<error_code>\S*)\s*desc="(?P<desc>[^"]*)"\s*method=(?P<method>\S*)\s*path="(?P<path>[^"]*)"\s*host=(?P<host>\S*)\s*(request_id=)?(?P<request_id>\S*)\s*fwd="?(?P<fwd>[^"\s]*)"?\s*dyno=(?P<dyno>\S*)\s*connect=(?P<connect>\d*)(ms)?\s*service=(?P<service>\d*)(ms)?\s*status=(?P<status>\d*)\s*bytes=(?P<bytes>\S*)\s*(protocol=)?(?P<protocol>[^"\s]*)$'

    return {
        "rule_group": {
            "name": "Heroku Router Log Parser",
            "description": "Parses Heroku L/H type router and dyno logs",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse Heroku Router Log",
                            "description": "Extract sock, severity, error_code, method, path, host, dyno, status, etc.",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule for Heroku Router",
                "description": "Add a PARSE rule to extract key=value pairs from Heroku router logs.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["sock", "severity", "error_code", "desc", "method", "path", "host", "fwd", "dyno", "connect", "service", "status", "bytes"],
            },
        ],
    }


def generate_apache_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Apache combined logs."""
    regex = r'^(?P<remote_addr>\S+)\s+-\s+(?P<remote_user>\S+)\s+\[(?P<time_local>[^\]]+)\]\s+"(?P<request>[^"]*)"\s+(?P<status>\d+)\s+(?P<body_bytes_sent>\d+)\s+"(?P<http_referer>[^"]*)"\s+"(?P<http_user_agent>[^"]*)"'

    return {
        "rule_group": {
            "name": "Apache Combined Log Parser",
            "description": "Parses Apache HTTP Server combined log format",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse Apache Combined Log",
                            "description": "Extract remote_addr, request, status, and other fields",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Parse Apache date format",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.time_local",
                            "order": 1,
                            "timeFormat": "%d/%b/%Y:%H:%M:%S %z",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule",
                "description": "Add a PARSE rule to extract structured fields from Apache combined log.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["remote_addr", "remote_user", "time_local", "request", "status", "body_bytes_sent", "http_referer", "http_user_agent"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT Rule",
                "description": "Extract timestamp from time_local field.",
                "rule_type": "timestampextract",
                "source_field": "text.time_local",
                "time_format": "%d/%b/%Y:%H:%M:%S %z",
            },
        ],
    }


def generate_json_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for JSON logs."""
    return {
        "rule_group": {
            "name": "JSON Log Parser",
            "description": "Extracts fields from JSON structured logs - JSON EXTRACT maps level to severity",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Extract level to severity",
                            "description": "Map JSON 'level' field to Coralogix severity (INFO, ERROR, WARN, DEBUG)",
                            "enabled": True,
                            "type": "jsonextract",
                            "sourceField": "text",
                            "destinationField": "severity",
                            "order": 1,
                            "rule": "level",
                        },
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Use JSON EXTRACT for key fields",
                "description": "For JSON logs, use JSON EXTRACT rules to map JSON keys to Coralogix fields. Common mappings: level→severity, message→text, timestamp→(use TIMESTAMP EXTRACT).",
                "rule_type": "jsonextract",
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT if needed",
                "description": "If your JSON has a timestamp field (e.g., timestamp, time, @timestamp), add a TIMESTAMP EXTRACT rule with sourceField pointing to that field.",
                "rule_type": "timestampextract",
            },
        ],
    }


def generate_syslog_rfc5424_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Syslog RFC 5424."""
    regex = r'^<(?P<priority>\d+)>(?P<version>\d+)\s+(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)\s+(?P<hostname>\S+)\s+(?P<app_name>\S+)\s+(?P<procid>\S+)\s+(?P<msgid>\S+)\s+(?P<structured_data>\S*)\s*(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "Syslog RFC 5424 Parser",
            "description": "Parses structured syslog (RFC 5424) format",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse Syslog RFC 5424",
                            "description": "Extract priority, timestamp, hostname, app_name, message",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Use syslog timestamp as log timestamp",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.timestamp",
                            "order": 1,
                            "timeFormat": "%Y-%m-%dT%H:%M:%S.%f%z",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule for RFC 5424",
                "description": "Extract priority, version, timestamp, hostname, app_name, procid, msgid, and message.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["priority", "version", "timestamp", "hostname", "app_name", "procid", "msgid", "structured_data", "message"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT",
                "description": "Extract timestamp from the parsed timestamp field.",
                "rule_type": "timestampextract",
                "source_field": "text.timestamp",
            },
        ],
    }


def generate_linux_auth_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Linux auth.log/secure (PAM, SSH)."""
    # Base RFC 3164: timestamp hostname tag[pid]: message
    base_regex = r'^(?P<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<hostname>\S+)\s+(?P<tag>\S+?)(\[(?P<pid>\d+)\])?:\s*(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "Linux auth.log / secure Parser",
            "description": "Parses PAM auth.log and secure - SSH, sudo, login, session. Extracts user, ip, auth_method, status.",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse Syslog RFC 3164 (auth)",
                            "description": "Extract timestamp, hostname, tag, pid, message",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": base_regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Parse BSD syslog timestamp",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.timestamp",
                            "order": 1,
                            "timeFormat": "%b %d %H:%M:%S",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Parse Syslog Base",
                "description": "Extract timestamp, hostname, tag (sshd/sudo/su), pid, message.",
                "rule_type": "parse",
                "regex": base_regex,
                "fields_extracted": ["timestamp", "hostname", "tag", "pid", "message"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT",
                "description": "Parse BSD timestamp for auth events.",
                "rule_type": "timestampextract",
                "source_field": "text.timestamp",
                "time_format": "%b %d %H:%M:%S",
            },
        ],
    }


def generate_linux_syslog_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Linux syslog/messages."""
    return generate_syslog_rfc3164_parser(log_sample)


def generate_linux_kern_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Linux kern.log."""
    return generate_syslog_rfc3164_parser(log_sample)


def generate_linux_cron_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Linux cron logs."""
    return generate_syslog_rfc3164_parser(log_sample)


def generate_linux_dpkg_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Linux dpkg.log."""
    # dpkg: "2025-03-09 10:15:32 status installed nginx:amd64 1.24.0-1" or "2025-03-09 10:15:32 startup packages purge"
    regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(?P<action>\S+)\s+(?P<details>.*)$'

    return {
        "rule_group": {
            "name": "Linux dpkg.log Parser",
            "description": "Parses Debian/Ubuntu package manager logs - status, install, remove, configure",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse dpkg Log",
                            "description": "Extract timestamp, action (status/startup/configure), details",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Parse dpkg timestamp",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.timestamp",
                            "order": 1,
                            "timeFormat": "%Y-%m-%d %H:%M:%S",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule for dpkg",
                "description": "Extract timestamp, action (status/startup/configure), details (package+version or startup args).",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["timestamp", "action", "details"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT",
                "description": "Parse dpkg timestamp format.",
                "rule_type": "timestampextract",
                "source_field": "text.timestamp",
                "time_format": "%Y-%m-%d %H:%M:%S",
            },
        ],
    }


def generate_linux_mail_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Linux mail.log (Postfix)."""
    return generate_syslog_rfc3164_parser(log_sample)


def generate_otel_json_body_parser(log_sample: str) -> dict:
    """Extract logRecord.body when text contains full OTEL JSON. Puts body in text.body for downstream parsers."""
    # When text is full OTEL JSON, extract body. Downstream parsers use text.body
    regex = r'"body"\s*:\s*"(?P<body>[^"]*)"'

    return {
        "rule_group": {
            "name": "OTEL JSON Body Extractor",
            "description": "Extracts logRecord.body when text contains full OTEL JSON - downstream parsers use text.body",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Extract body from OTEL JSON",
                            "description": "When text is full OTEL JSON, extract logRecord.body to text.body",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
            ],
        },
        "steps": [],
    }


def generate_otel_linux_syslog_parser(log_sample: str) -> dict:
    """Generate parser for OTEL logRecord.body format: ISO_TIMESTAMP hostname tag: message."""
    # journald/syslog from otelcol: 2026-03-09T18:08:38.510893+05:30 asus kernel: message
    regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z)?)\s+(?P<hostname>\S+)\s+(?P<tag>\S+):\s*(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "OTEL Linux Syslog (journald)",
            "description": "Parses logRecord.body from otelcol: ISO timestamp, hostname, tag, message",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse OTEL syslog body (text)",
                            "description": "When text is body directly",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        },
                        {
                            "name": "Parse OTEL syslog body (text.body)",
                            "description": "When body extracted from OTEL JSON",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text.body",
                            "destinationField": "text",
                            "order": 2,
                            "rule": regex,
                        },
                    ],
                },
            ],
        },
        "steps": [],
    }


def generate_otel_linux_secure_parser(log_sample: str) -> dict:
    """Generate parser for OTEL Linux secure and cron logs. EXTRACT only - original log unchanged, adds new JSON keys."""
    # RFC 3164 base: Mar  9 13:41:05 hostname tag[pid]: message (works for secure, cron)
    auth_regex = r'^(?P<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<hostname>\S+)\s+(?P<tag>\S+?)(\[(?P<pid>\d+)\])?:\s*(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "OTEL Linux secure & cron (auth.log, cron)",
            "description": "EXTRACT only - keeps original log intact, adds new JSON keys: body, source, timestamp, hostname, tag, pid, message, user, src_ip, action, eventtype, dest, cron_cmd, host, dvc, process, app",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                # Order 1: Extract body and source from OTEL JSON (text unchanged)
                {
                    "order": 1,
                    "rules": [
                        {"name": "Extract body from OTEL JSON", "enabled": True, "type": "extract", "sourceField": "text", "order": 1, "rule": r'"body"\s*:\s*"(?P<body>[^"]*)"'},
                        {"name": "Extract source (log.file.name)", "enabled": True, "type": "extract", "sourceField": "text", "order": 2, "rule": r'"log\.file\.name"\s*:\s*"(?P<source>[^"]*)"'},
                    ],
                },
                # Order 2: Extract RFC 3164 fields from text (when raw) or body (when JSON) - adds timestamp, hostname, tag, pid, message
                {
                    "order": 2,
                    "rules": [
                        {"name": "Extract syslog from text", "enabled": True, "type": "extract", "sourceField": "text", "order": 1, "rule": auth_regex},
                        {"name": "Extract syslog from body", "enabled": True, "type": "extract", "sourceField": "body", "order": 2, "rule": auth_regex},
                    ],
                },
                # Order 3: Extract auth/cron fields from message - adds user, src_ip, action, eventtype, dest, cron_cmd
                {
                    "order": 3,
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
                # Order 4: Extract host, dvc, process, app from hostname/tag (aliases)
                {
                    "order": 4,
                    "rules": [
                        {"name": "Extract host from hostname", "enabled": True, "type": "extract", "sourceField": "hostname", "order": 1, "rule": r"^(?P<host>.+)$"},
                        {"name": "Extract dvc from hostname", "enabled": True, "type": "extract", "sourceField": "hostname", "order": 2, "rule": r"^(?P<dvc>.+)$"},
                        {"name": "Extract process from tag", "enabled": True, "type": "extract", "sourceField": "tag", "order": 3, "rule": r"^(?P<process>.+)$"},
                        {"name": "Extract app from tag", "enabled": True, "type": "extract", "sourceField": "tag", "order": 4, "rule": r"^(?P<app>.+)$"},
                        {"name": "Extract src from src_ip", "enabled": True, "type": "extract", "sourceField": "src_ip", "order": 5, "rule": r"^(?P<src>.+)$"},
                        {"name": "Extract user_name from user", "enabled": True, "type": "extract", "sourceField": "user", "order": 6, "rule": r"^(?P<user_name>.+)$"},
                    ],
                },
            ],
        },
        "steps": [
            {"step": 1, "title": "Extract body and source", "description": "From OTEL JSON - adds body, source. Original text unchanged.", "rule_type": "extract"},
            {"step": 2, "title": "Extract syslog fields", "description": "From text or body - adds timestamp, hostname, tag, pid, message.", "rule_type": "extract"},
            {"step": 3, "title": "Extract auth/cron fields", "description": "From message - adds user, src_ip, action, eventtype, dest, cron_cmd.", "rule_type": "extract"},
            {"step": 4, "title": "Extract aliases", "description": "From hostname/tag - adds host, dvc, process, app, src, user_name.", "rule_type": "extract"},
        ],
    }


def generate_otel_linux_ufw_parser(log_sample: str) -> dict:
    """Generate parser for UFW logs - parse base + extract SRC, DST, IN, OUT, PROTO."""
    base_regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z)?)\s+(?P<hostname>\S+)\s+(?P<tag>\S+):\s*(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "OTEL Linux UFW",
            "description": "Parses UFW logs from otelcol - extracts SRC, DST, IN, OUT, PROTO from [UFW BLOCK]",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse UFW body (text)",
                            "description": "When text is body directly",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": base_regex,
                        },
                        {
                            "name": "Parse UFW body (text.body)",
                            "description": "When body extracted from OTEL JSON",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text.body",
                            "destinationField": "text",
                            "order": 2,
                            "rule": base_regex,
                        },
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract SRC IP",
                            "description": "Extract source IP from UFW message",
                            "enabled": True,
                            "type": "extract",
                            "sourceField": "text.message",
                            "order": 1,
                            "rule": r"SRC=(?P<src>\d+\.\d+\.\d+\.\d+)",
                        },
                        {
                            "name": "Extract DST IP",
                            "description": "Extract destination IP from UFW message",
                            "enabled": True,
                            "type": "extract",
                            "sourceField": "text.message",
                            "order": 2,
                            "rule": r"DST=(?P<dst>\d+\.\d+\.\d+\.\d+)",
                        },
                        {
                            "name": "Extract IN interface",
                            "description": "Extract input interface",
                            "enabled": True,
                            "type": "extract",
                            "sourceField": "text.message",
                            "order": 3,
                            "rule": r"IN=(?P<in>\S+)",
                        },
                        {
                            "name": "Extract PROTO",
                            "description": "Extract protocol number",
                            "enabled": True,
                            "type": "extract",
                            "sourceField": "text.message",
                            "order": 4,
                            "rule": r"PROTO=(?P<proto>\d+)",
                        },
                    ],
                },
            ],
        },
        "steps": [],
    }


def generate_syslog_rfc3164_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Syslog RFC 3164 (BSD)."""
    regex = r'^(?P<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<hostname>\S+)\s+(?P<tag>\S+?)(\[(?P<pid>\d+)\])?:\s*(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "Syslog RFC 3164 (BSD) Parser",
            "description": "Parses traditional BSD syslog format",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse BSD Syslog",
                            "description": "Extract timestamp, hostname, tag, pid, message",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Parse BSD syslog timestamp (e.g., Mar  5 10:15:32)",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.timestamp",
                            "order": 1,
                            "timeFormat": "%b %d %H:%M:%S",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule for BSD Syslog",
                "description": "Extract timestamp, hostname, tag, pid, and message.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["timestamp", "hostname", "tag", "pid", "message"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT",
                "description": "Parse the BSD timestamp format (e.g., Mar  5 10:15:32). Note: year may need adjustment for current year.",
                "rule_type": "timestampextract",
                "source_field": "text.timestamp",
                "time_format": "%b %d %H:%M:%S",
            },
        ],
    }


def generate_java_log_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Java Log4j/Logback logs."""
    regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(?P<level>DEBUG|INFO|WARN|ERROR)\s+\[(?P<thread>[^\]]+)\]\s+(?P<logger>\S+)\s+-\s+(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "Java Log4j/Logback Parser",
            "description": "Parses Java application logs",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse Java Log",
                            "description": "Extract timestamp, level, thread, logger, message",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Parse Java log timestamp",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.timestamp",
                            "order": 1,
                            "timeFormat": "%Y-%m-%d %H:%M:%S.%f",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule",
                "description": "Extract timestamp, level, thread, logger, and message from Java logs.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["timestamp", "level", "thread", "logger", "message"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT",
                "description": "Extract timestamp for proper log ordering.",
                "rule_type": "timestampextract",
                "source_field": "text.timestamp",
            },
        ],
    }


def generate_docker_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Docker JSON logs."""
    return {
        "rule_group": {
            "name": "Docker Container Log Parser",
            "description": "Parses Docker JSON log format - extracts stream to category",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Extract stream to category",
                            "description": "Map stdout/stderr to Coralogix category",
                            "enabled": True,
                            "type": "jsonextract",
                            "sourceField": "text",
                            "destinationField": "category",
                            "order": 1,
                            "rule": "stream",
                        },
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Use Docker time field (if available in your integration)",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "time",
                            "order": 1,
                            "timeFormat": "%Y-%m-%dT%H:%M:%S.%fZ",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Use JSON EXTRACT for stream",
                "description": "Docker logs are JSON with 'log', 'stream', and 'time' fields. Extract 'stream' to category for stdout/stderr.",
                "rule_type": "jsonextract",
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT (optional)",
                "description": "If your integration exposes the 'time' field, add TIMESTAMP EXTRACT with sourceField 'time'.",
                "rule_type": "timestampextract",
                "source_field": "time",
            },
        ],
    }


def generate_kubernetes_parser(log_sample: str) -> dict:
    """Generate Coralogix parsing rules for Kubernetes container logs."""
    regex = r'^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(?P<level>DEBUG|INFO|WARN|ERROR)\s+\[(?P<thread>[^\]]+)\]\s+(?P<logger>[^\s]+)\s+(?P<message>.*)$'

    return {
        "rule_group": {
            "name": "Kubernetes Container Log Parser",
            "description": "Parses Kubernetes pod/container stdout logs",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": [
                {
                    "order": 1,
                    "rules": [
                        {
                            "name": "Parse Kubernetes Log",
                            "description": "Extract timestamp, level, thread, logger, message",
                            "enabled": True,
                            "type": "parse",
                            "sourceField": "text",
                            "destinationField": "text",
                            "order": 1,
                            "rule": regex,
                        }
                    ],
                },
                {
                    "order": 2,
                    "rules": [
                        {
                            "name": "Extract Timestamp",
                            "description": "Parse ISO 8601 timestamp",
                            "enabled": True,
                            "type": "timestampextract",
                            "sourceField": "text.timestamp",
                            "order": 1,
                            "timeFormat": "%Y-%m-%dT%H:%M:%S.%fZ",
                            "formatStandard": "strftime",
                        }
                    ],
                },
            ],
        },
        "steps": [
            {
                "step": 1,
                "title": "Create PARSE Rule",
                "description": "Extract timestamp, level, thread, logger, and message from Kubernetes container logs.",
                "rule_type": "parse",
                "regex": regex,
                "fields_extracted": ["timestamp", "level", "thread", "logger", "message"],
            },
            {
                "step": 2,
                "title": "Add TIMESTAMP EXTRACT",
                "description": "Parse ISO 8601 timestamp for proper log ordering.",
                "rule_type": "timestampextract",
                "source_field": "text.timestamp",
            },
        ],
    }


def analyze_log_format(log_sample: str) -> dict:
    """
    Analyze log sample and detect format type + extract patterns.
    Returns dict with: format_type, parse_rule, timestamp_format, timestamp_field, fields.
    """
    sample = log_sample.strip()
    first_line = sample.split("\n")[0] if sample else ""
    result = {"format_type": "plain", "parse_rule": None, "timestamp_format": None, "timestamp_field": None, "fields": ["message"]}

    # 1. JSON detection
    try:
        obj = json.loads(first_line)
        if isinstance(obj, dict):
            result["format_type"] = "json"
            result["fields"] = list(obj.keys())[:12]  # Limit for parser
            if "timestamp" in obj or "time" in obj or "@timestamp" in obj:
                result["timestamp_field"] = next((k for k in ["@timestamp", "timestamp", "time"] if k in obj), None)
            return result
    except (json.JSONDecodeError, ValueError):
        pass

    # 2. RFC 3164 syslog: "Mar  5 10:15:32 hostname tag: message"
    rfc3164 = re.match(
        r"^(?P<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<hostname>\S+)\s+(?P<tag>\S+?)(\[(?P<pid>\d+)\])?:\s*(?P<message>.*)$",
        first_line,
    )
    if rfc3164:
        result["format_type"] = "rfc3164"
        result["parse_rule"] = r"^(?P<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<hostname>\S+)\s+(?P<tag>\S+?)(\[(?P<pid>\d+)\])?:\s*(?P<message>.*)$"
        result["timestamp_format"] = "%b %d %H:%M:%S"
        result["timestamp_field"] = "timestamp"
        result["fields"] = ["timestamp", "hostname", "tag", "pid", "message"]
        return result

    # 3. ISO 8601 timestamp + level + message (e.g. Java, Python logging)
    iso_level = re.match(
        r"^(?P<timestamp>\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\s+(?P<level>\w+)\s+(?P<message>.*)$",
        first_line,
    )
    if iso_level:
        result["format_type"] = "iso_level"
        result["parse_rule"] = r"^(?P<timestamp>\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\s+(?P<level>\w+)\s+(?P<message>.*)$"
        result["timestamp_format"] = "%Y-%m-%dT%H:%M:%S.%fZ"
        result["timestamp_field"] = "timestamp"
        result["fields"] = ["timestamp", "level", "message"]
        return result

    # 4. Key=value pairs (Heroku-style, key=val key2=val2)
    kv_matches = re.findall(r"(\w+)=(?:\"([^\"]*)\"|(\S+))", first_line)
    if len(kv_matches) >= 2:
        result["format_type"] = "key_value"
        # Build regex: capture each key=value
        keys = []
        for m in kv_matches:
            keys.append(m[0])
        result["fields"] = keys[:10]
        # Generic key=value extract - use extract rules per field
        result["parse_rule"] = "key_value"  # Signal to use extract rules
        return result

    # 5. Key: value (colon-separated)
    colon_matches = re.findall(r"(\w+):\s*([^\s]+(?:\s+[^\w:]+)?)", first_line)
    if len(colon_matches) >= 2:
        result["format_type"] = "key_colon_value"
        result["fields"] = [m[0] for m in colon_matches][:8]
        result["parse_rule"] = "key_colon_value"
        return result

    # 6. ISO timestamp only at start
    iso_only = re.match(r"^(?P<timestamp>\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\s+(?P<message>.*)$", first_line)
    if iso_only:
        result["format_type"] = "iso_message"
        result["parse_rule"] = r"^(?P<timestamp>\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\s+(?P<message>.*)$"
        result["timestamp_format"] = "%Y-%m-%dT%H:%M:%S.%fZ"
        result["timestamp_field"] = "timestamp"
        result["fields"] = ["timestamp", "message"]
        return result

    # 7. Fallback: capture full message
    result["parse_rule"] = r"^(?P<message>.*)$"
    return result


def generate_generic_parser(log_sample: str, source_id: str) -> dict:
    """Generate a parser for any log format. Auto-detects structure and builds appropriate rules."""
    analysis = analyze_log_format(log_sample)
    fmt = analysis["format_type"]
    name = f"Parser for {source_id}" if source_id and source_id != "generic" else "Custom Log Parser"

    rules_groups = []
    order = 1

    if fmt == "json":
        return generate_json_parser(log_sample)

    if fmt in ("rfc3164", "iso_level", "iso_message") and analysis["parse_rule"]:
        rules_groups.append({
            "order": order,
            "rules": [
                {
                    "name": f"Parse {fmt} format",
                    "description": f"Extract {', '.join(analysis['fields'])}",
                    "enabled": True,
                    "type": "parse",
                    "sourceField": "text",
                    "destinationField": "text",
                    "order": 1,
                    "rule": analysis["parse_rule"],
                }
            ],
        })
        order += 1
        if analysis["timestamp_format"] and analysis["timestamp_field"]:
            rules_groups.append({
                "order": order,
                "rules": [
                    {
                        "name": "Extract Timestamp",
                        "description": "Parse timestamp for log ordering",
                        "enabled": True,
                        "type": "timestampextract",
                        "sourceField": f"text.{analysis['timestamp_field']}",
                        "order": 1,
                        "timeFormat": analysis["timestamp_format"],
                        "formatStandard": "strftime",
                    }
                ],
            })
            order += 1

    elif fmt == "key_value":
        # Build extract rules for key=value pairs (key="val" or key=val)
        extract_rules = []
        for i, key in enumerate(analysis["fields"][:8], 1):
            safe_key = re.sub(r"\W", "_", key)[:50]  # Valid group name
            extract_rules.append({
                "name": f"Extract {key}",
                "enabled": True,
                "type": "extract",
                "sourceField": "text",
                "order": i,
                "rule": rf'{re.escape(key)}=(?:"(?P<{safe_key}>[^"]*)"|(?P<{safe_key}>\S+))',
            })
        rules_groups.append({"order": 1, "rules": extract_rules})

    else:
        # Plain / unknown: parse with message capture
        rules_groups.append({
            "order": 1,
            "rules": [
                {
                    "name": "Capture message",
                    "description": "Add named groups (?P<fieldname>pattern) for your format. Use regex101.com to build.",
                    "enabled": True,
                    "type": "parse",
                    "sourceField": "text",
                    "destinationField": "text",
                    "order": 1,
                    "rule": analysis["parse_rule"] or r"^(?P<message>.*)$",
                }
            ],
        })

    return {
        "rule_group": {
            "name": name,
            "description": f"Auto-generated for {fmt} format. Review and customize as needed.",
            "enabled": True,
            "ruleMatchers": [],
            "rulesGroups": rules_groups,
        },
        "steps": [
            {"step": 1, "title": "Format detected", "description": f"Detected: {fmt}. Adjust rules if needed.", "rule_type": "parse"},
            {"step": 2, "title": "Customize", "description": "Edit regex at regex101.com. Use (?P<field>pattern) for extraction.", "rule_type": "parse"},
            {"step": 3, "title": "Timestamp", "description": "Add TIMESTAMP EXTRACT if your log has timestamps.", "rule_type": "timestampextract"},
        ],
    }


PARSER_GENERATORS = {
    "nginx_access": generate_nginx_access_parser,
    "nginx_error": generate_generic_parser,
    "apache_combined": generate_apache_parser,
    "heroku_router": generate_heroku_parser,
    "json": generate_json_parser,
    "syslog_rfc5424": generate_syslog_rfc5424_parser,
    "syslog_rfc3164": generate_syslog_rfc3164_parser,
    "kubernetes": generate_kubernetes_parser,
    "aws_cloudwatch": generate_generic_parser,
    "java_log4j": generate_java_log_parser,
    "docker": generate_docker_parser,
    # Linux /var/log parsers
    "linux_auth": generate_linux_auth_parser,
    "linux_syslog": generate_linux_syslog_parser,
    "linux_kern": generate_linux_kern_parser,
    "linux_cron": generate_linux_cron_parser,
    "linux_dpkg": generate_linux_dpkg_parser,
    "linux_mail": generate_linux_mail_parser,
    # OTEL / otelcol-contrib format (logRecord.body)
    "otel_linux_syslog": generate_otel_linux_syslog_parser,
    "otel_linux_ufw": generate_otel_linux_ufw_parser,
    "otel_linux_secure": generate_otel_linux_secure_parser,
    "otel_json_body": generate_otel_json_body_parser,
}


def generate_parser(log_sample: str = "", source_id: str = "") -> dict:
    """Generate Coralogix parsing rules. Provide log_sample and/or source_id."""
    log_sources = load_log_sources()
    source = None
    if source_id:
        for s in log_sources:
            if s["id"] == source_id:
                source = s
                break
        if not source:
            raise ValueError(f"Source not found: {source_id}")
    else:
        matches = identify_log_source(log_sample or "", log_sources)
        if matches:
            source = matches[0]["source"]
        else:
            source = {"id": "generic", "name": "Generic", "parser_type": "generic"}

    sample = log_sample or source.get("sample_log", "")
    parser_type = source.get("parser_type", "generic")

    def _generic(s, sid=None):
        return generate_generic_parser(s, sid or source.get("name", "Unknown"))

    generator = PARSER_GENERATORS.get(parser_type, _generic)
    result = generator(sample)
    return {
        "source": source,
        "rule_group": result["rule_group"],
        "steps": result["steps"],
    }


def deploy_to_coralogix(rule_group: dict, api_key: str, endpoint: str) -> bool:
    """Deploy a rule group to Coralogix. Returns True on success."""
    endpoint = endpoint.strip()
    if endpoint.startswith("https://"):
        endpoint = endpoint.replace("https://", "")
    if endpoint.startswith("api."):
        endpoint = endpoint.replace("api.", "")

    url = f"https://api.{endpoint}/api/v1/external/rule/rule-set"
    payload = json.dumps(rule_group).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": "Coralogix-Parser-Builder/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status in (200, 201)


def list_sources() -> list:
    """List all supported log sources."""
    return load_log_sources()


def add_log_source(
    source_id: str,
    name: str,
    description: str = "",
    sample_log: str = "",
    parser_type: str = "generic",
    patterns: list = None,
) -> dict:
    """
    Add a new log source to log_sources.json.
    Returns the new source dict. Use parser_type='generic' for auto-detection.
    """
    sources = load_log_sources()
    for s in sources:
        if s["id"] == source_id:
            raise ValueError(f"Source id '{source_id}' already exists")

    if not patterns and sample_log:
        analysis = analyze_log_format(sample_log)
        if analysis["format_type"] == "rfc3164":
            patterns = [r"^[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\S+\s+\S+.*"]
        elif analysis["format_type"] == "json":
            patterns = [r"^\s*\{.*\}\s*$"]
        elif analysis["format_type"] == "key_value":
            patterns = [r"\w+=\S+"]
        else:
            patterns = [r".*"]

    new_source = {
        "id": source_id,
        "name": name,
        "description": description or f"Custom log source: {name}",
        "patterns": patterns or [r".*"],
        "sample_log": sample_log or "",
        "parser_type": parser_type,
    }
    sources.append(new_source)
    data = {"log_sources": sources}
    with open(LOG_SOURCES_FILE, "w") as f:
        json.dump(data, f, indent=2)
    return new_source


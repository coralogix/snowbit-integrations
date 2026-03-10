# Coralogix Parser Builder

A CLI tool to **create parsers for any log source**, identify formats, generate Coralogix parsing rules, and deploy them. Ready for team use.

> **Publish to [coralogix/snowbit-integrations](https://github.com/coralogix/snowbit-integrations):** See [PUBLISH.md](PUBLISH.md) for instructions.

## Quick Start

**Chat-first (recommended):** Open in Cursor, paste a log sample, and say *"Create a parser for this log"*. The AI does the rest – no CLI needed.

**CLI:**

```bash
cd coralogix-parser-builder
cp .env.example .env   # Add your CORALOGIX_API_KEY and CORALOGIX_ENDPOINT

# Create parser for ANY log (auto-detects format)
python cli.py generate --sample mylog.txt -o parser.json
python cli.py deploy --rule-file parser.json

# Identify known formats
python cli.py identify mylog.txt

# Add new source to catalog (for reuse)
python cli.py add-source mylog.txt --id my_app --name "My App Logs"

# List supported sources
python cli.py list-sources
```

## Create Parser for Any Log Source

The tool **auto-detects** log format and generates appropriate rules:

| Format | Auto-detected | Example |
|--------|---------------|---------|
| JSON | ✓ | `{"level":"info","msg":"started"}` |
| RFC 3164 syslog | ✓ | `Mar 5 10:15:32 host sshd[123]: Accepted` |
| ISO + level | ✓ | `2025-03-05T10:15:32Z INFO message` |
| Key=value | ✓ | `host=foo method=GET path=/api` |
| Plain text | ✓ | Fallback with message capture |

Use `add-source` to register new formats for your team.

## Use in Cursor

1. **Add to your project**: Copy this repo or add as submodule
2. **Chat with Cursor**: Share log samples and ask to create/deploy parsers
3. **CLI from terminal**: Run `python cli.py` from the coralogix-parser-builder directory

## Supported Log Sources

| Source ID | Description |
|-----------|-------------|
| nginx_access | NGINX combined/access log |
| nginx_error | NGINX error log |
| apache_combined | Apache combined log |
| heroku_router | Heroku router logs |
| json | JSON structured logs |
| syslog_rfc5424 | Syslog RFC 5424 |
| syslog_rfc3164 | BSD syslog |
| kubernetes | K8s container logs |
| java_log4j | Java Log4j/Logback |
| docker | Docker JSON logs |
| linux_auth | auth.log, secure |
| linux_syslog | syslog, messages |
| linux_dpkg | dpkg.log |
| otel_linux_syslog | OTEL journald/syslog |
| otel_linux_ufw | UFW logs |
| ... | Run `list-sources` for full list |

## Deployment Options

| Method | Use case |
|--------|----------|
| `cli.py deploy` | Deploy from sample, source, or rule file (Management API) |
| `deploy_mgmt_api.py` | Deploy a JSON rule file directly |
| `deploy_linux_parsers.py` | Pre-built Linux parsers (auth, syslog, dpkg, UFW) |
| Terraform | Infrastructure-as-code; see `terraform/README.md` |

**Deploy uses Coralogix Management API** – works for all regions (eu1, cx498, etc.). API key must have PARSINGRULES role.

## Deploy Linux Parsers (otelcol)

For pre-built Linux log parsers (auth, syslog, dpkg, UFW):

```bash
export CORALOGIX_API_KEY="your-api-key"
export CORALOGIX_ENDPOINT="eu1.coralogix.com"
python deploy_linux_parsers.py --dry-run   # Preview
python deploy_linux_parsers.py             # Deploy
```

## Python API

```python
from parser import identify_log_source, generate_parser, deploy_to_coralogix, list_sources

# Identify
sources = list_sources()
matches = identify_log_source(log_sample, sources)

# Generate
result = generate_parser(log_sample="...", source_id="nginx_access")
rule_group = result["rule_group"]

# Deploy (Management API)
from deploy_mgmt_api import deploy_from_dict
deploy_from_dict(rule_group, api_key="...", endpoint="eu1.coralogix.com")
```

## Coralogix API Domains

- **EU1**: `eu1.coralogix.com`
- **US2 (cx498)**: `cx498.coralogix.com`
- **US1**: `coralogix.us`
- **AP1**: `coralogix.in`

## Team Onboarding

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, adding new sources, and troubleshooting.

## References

- [Coralogix Log Parsing Rules](https://coralogix.com/docs/user-guides/data-transformation/parsing/log-parsing-rules)
- [Parsing Rules API](https://coralogix.com/docs/developer-portal/apis/data-management/parsing-rules-api)

# Contributing to Coralogix Parser Builder

## Quick Start for Team Members

### 1. Setup

```bash
cd coralogix-parser-builder
cp .env.example .env
# Edit .env: add your CORALOGIX_API_KEY and CORALOGIX_ENDPOINT
```

### 2. Create a Parser – Chat-First (Recommended)

**Use Cursor chat – no Python commands needed**

1. Open this project in Cursor.
2. Start a chat and paste your log sample.
3. Say: *"Create a parser for this log"* or *"Parse this log format"*.
4. The AI will generate the parser, show it, and optionally save or deploy it.

You don't need to run `python cli.py` – the AI uses the parser builder code directly.

### 3. Create a Parser – CLI (Optional)

**Option A: From a log sample (auto-detect format)**

```bash
# Identify if we already support this format
python cli.py identify mylog.txt

# Generate parser (works for known + unknown formats)
python cli.py generate --sample mylog.txt -o parsers/my_parser.json

# Deploy to your Coralogix account
export CORALOGIX_API_KEY="your-key"
python cli.py deploy --rule-file parsers/my_parser.json
```

**Option B: Add as a new reusable source (CLI)**

```bash
# Add new source to the catalog
python cli.py add-source mylog.txt --id my_app_logs --name "My App Logs"

# Generate and deploy
python cli.py generate --source my_app_logs -o parsers/my_app.json
python cli.py deploy --rule-file parsers/my_app.json
```

### 4. Supported Formats (Auto-Detected)

| Format | Description |
|--------|-------------|
| `json` | JSON structured logs |
| `rfc3164` | BSD syslog (Mar 5 10:15:32 host tag: message) |
| `iso_level` | ISO timestamp + level + message |
| `iso_message` | ISO timestamp + message |
| `key_value` | key=value or key="value" pairs |
| `plain` | Fallback: full message capture |

### 5. Adding a New Log Source (Manual – for advanced use)

1. Add an entry to `data/log_sources.json`:

```json
{
  "id": "my_source",
  "name": "My Source",
  "description": "Description",
  "patterns": ["regex pattern to match logs"],
  "sample_log": "sample log line",
  "parser_type": "generic"
}
```

2. For custom parsing logic, add a generator in `parser.py` and register in `PARSER_GENERATORS`.

3. Test: `python cli.py generate --source my_source -o test.json`

### 5. Deployment

- **CLI deploy** uses the Coralogix Management API (works for all regions including cx498).
- **Terraform**: See `terraform/README.md` for infrastructure-as-code.
- **Manual**: Use `deploy_mgmt_api.py` with a JSON file.

### 6. API Key Requirements

Your API key must have the **PARSINGRULES** role (create/write). Create one in Coralogix → Settings → API Keys.

### 7. Regions / Endpoints

| Region | Endpoint |
|--------|----------|
| EU1 | eu1.coralogix.com |
| US2 (cx498) | cx498.coralogix.com |
| US1 | coralogix.us |
| AP1 | coralogix.in |

### 8. Customizing a Generated Parser

1. Generate: `python cli.py generate --sample mylog.txt -o parser.json`
2. Edit `parser.json` – adjust regex, add fields, change timestamp format
3. Test at [regex101.com](https://regex101.com) for your regex
4. Deploy: `python cli.py deploy --rule-file parser.json`

### 9. Troubleshooting

- **403 on deploy**: Ensure API key has PARSINGRULES role
- **400 on deploy**: Check rule JSON format; ensure `sourceField` uses `text.` prefix for extracted fields
- **Parser not matching**: Run `identify` first; add patterns to `log_sources.json` and re-run `add-source`

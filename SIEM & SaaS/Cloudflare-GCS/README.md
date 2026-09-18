# Cloudflare Logpush (GCS) to Coralogix

Google Cloud Function (2nd gen) that reads **Cloudflare Logpush** files from a GCS bucket and ships each log line to the Coralogix Logs API.

Cloudflare Logpush writes gzip-compressed NDJSON (one JSON object per line):

```
gs://<bucket>/<optional-prefix>/<YYYYMMDD>/<HHMMSS>_<id>.log.gz
```

```
GCS object finalized (.log.gz)
        |
        v
   Cloud Function (this function)
        |  ungzip + parse NDJSON
        v
Coralogix Logs API  POST https://ingress.<domain>/logs/v1/bulk
        applicationName: cloudflare
        subsystemName:   logpush
```

This path is for accounts that already land Logpush in GCS. If you also ship Cloudflare via another connector (HTTP Logpush to Coralogix, Cloudflare-to-Coralogix integration, etc.), running both will duplicate events.

## Prerequisites

- GCP project with billing, Cloud Functions, Eventarc, and Cloud Storage APIs enabled
- A GCS bucket that Cloudflare Logpush already writes to
- Coralogix Send-Your-Data API key (Coralogix -> **Data Flow -> API Keys**)
- Coralogix domain (`eu1.coralogix.com`, `us1.coralogix.com`, `coralogix.in`, ...)
- `gcloud` CLI authenticated to the project

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CORALOGIX_SEND_YOUR_DATA_KEY` | Yes | - | Send-Your-Data API key |
| `CORALOGIX_DOMAIN` | Yes | `coralogix.com` | e.g. `eu1.coralogix.com` |
| `CORALOGIX_APPLICATION_NAME` | No | `cloudflare` | Coralogix application |
| `CORALOGIX_SUBSYSTEM_NAME` | No | `logpush` | Coralogix subsystem |
| `GCS_KEY_PREFIX` | No | empty | Only process objects with this prefix |
| `GCS_KEY_SUFFIX` | No | empty | Object suffix filter (use `.gz` for Logpush) |
| `CORALOGIX_BATCH_SIZE` | No | `400` | Events per HTTP request |
| `CORALOGIX_TIMEOUT_SECONDS` | No | `60` | Ingest HTTP timeout |
| `CORALOGIX_MAX_RETRIES` | No | `4` | Retries on 429/5xx |
| `DRY_RUN` | No | `false` | Parse files but do not send |
| `INCLUDE_SOURCE_METADATA` | No | `false` | Attach `gcs_bucket` / `gcs_object` |
| `LOG_LEVEL` | No | `INFO` | Function logging |

`CORALOGIX_PRIVATE_KEY`, `CORALOGIX_APPLICATION`, and `CORALOGIX_SUBSYSTEM` are accepted as aliases.

## Deploy (Cloud Functions 2nd gen)

```bash
cd "snowbit-integrations/SIEM & SaaS/Cloudflare-GCS"

PROJECT_ID=your-gcp-project
REGION=us-central1
BUCKET=your-cloudflare-logpush-bucket
FUNCTION=cloudflare-gcs-coralogix

gcloud services enable \
  cloudfunctions.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  storage.googleapis.com \
  --project "$PROJECT_ID"

gcloud functions deploy "$FUNCTION" \
  --gen2 \
  --runtime python312 \
  --region "$REGION" \
  --source . \
  --entry-point ship_cloudflare_logs \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=${BUCKET}" \
  --memory 512MB \
  --timeout 540s \
  --max-instances 20 \
  --set-env-vars "CORALOGIX_DOMAIN=eu1.coralogix.com,CORALOGIX_APPLICATION_NAME=cloudflare,CORALOGIX_SUBSYSTEM_NAME=logpush,GCS_KEY_SUFFIX=.gz" \
  --set-secrets "CORALOGIX_SEND_YOUR_DATA_KEY=coralogix-send-your-data-key:latest"
```

If you prefer a plain environment variable instead of Secret Manager, replace `--set-secrets` with:

```bash
  --set-env-vars "CORALOGIX_SEND_YOUR_DATA_KEY=YOUR_KEY,CORALOGIX_DOMAIN=eu1.coralogix.com,CORALOGIX_APPLICATION_NAME=cloudflare,CORALOGIX_SUBSYSTEM_NAME=logpush,GCS_KEY_SUFFIX=.gz"
```

### IAM the function needs

The function's runtime service account must be able to read the Logpush bucket:

```bash
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gsutil iam ch "serviceAccount:${SA}:objectViewer" "gs://${BUCKET}"
```

Eventarc also needs the Eventarc service agent to invoke the function (usually granted automatically on first Gen2 GCS trigger deploy). If the trigger never fires, grant:

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver"
```

### Optional HTTP backfill function

The GCS trigger only fires for **new** objects. Deploy a second HTTP function from the same source to ship history:

```bash
gcloud functions deploy "${FUNCTION}-backfill" \
  --gen2 \
  --runtime python312 \
  --region "$REGION" \
  --source . \
  --entry-point backfill \
  --trigger-http \
  --no-allow-unauthenticated \
  --memory 512MB \
  --timeout 540s \
  --set-env-vars "CORALOGIX_DOMAIN=eu1.coralogix.com,CORALOGIX_APPLICATION_NAME=cloudflare,CORALOGIX_SUBSYSTEM_NAME=logpush,GCS_KEY_SUFFIX=.gz" \
  --set-secrets "CORALOGIX_SEND_YOUR_DATA_KEY=coralogix-send-your-data-key:latest"
```

Invoke one object:

```bash
gcloud functions call "${FUNCTION}-backfill" \
  --gen2 \
  --region "$REGION" \
  --data "{\"bucket\":\"${BUCKET}\",\"name\":\"path/to/file.log.gz\"}"
```

List and backfill a prefix:

```bash
gsutil ls "gs://${BUCKET}/**.gz" | while read -r uri; do
  name="${uri#gs://${BUCKET}/}"
  gcloud functions call "${FUNCTION}-backfill" \
    --gen2 \
    --region "$REGION" \
    --data "{\"bucket\":\"${BUCKET}\",\"name\":\"${name}\"}"
done
```

## Cloudflare Logpush destination

In Cloudflare, create (or keep) a Logpush job whose destination is this GCS bucket. Recommended:

- Dataset: HTTP requests, firewall events, audit logs, or DNS - whatever you need
- Output: NDJSON, gzip enabled
- Fields: include the fields you want searchable in Coralogix (`RayID`, `ClientIP`, `EdgeResponseStatus`, `ClientRequestHost`, `WAFAction`, ...)
- Path: a dedicated prefix such as `cloudflare/http/` then set `GCS_KEY_PREFIX=cloudflare/http/`

The function does not call the Cloudflare API. It only reads objects after Logpush writes them.

## Finding logs in Coralogix

```
applicationName:cloudflare AND subsystemName:logpush
applicationName:cloudflare AND EdgeResponseStatus:>=500
applicationName:cloudflare AND Action:block
applicationName:cloudflare AND ClientRequestHost:"example.com"
```

Each log `text` is the original Cloudflare JSON. After JSON parsing, fields such as `RayID`, `ClientIP`, `EdgeResponseStatus`, and `EdgeStartTimestamp` are available.

Severity:

| Condition | Level |
|-----------|-------|
| Firewall / WAF block or drop | Error (5) |
| Challenge | Warning (4) |
| HTTP status >= 500 | Error (5) |
| HTTP status >= 400 | Warning (4) |
| Everything else | Info (3) |

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| Function never runs | Eventarc GCS trigger, bucket name, Eventarc eventReceiver role |
| `Missing required environment variable` | `CORALOGIX_SEND_YOUR_DATA_KEY` |
| 403 on download | Runtime SA missing `objectViewer` on the bucket |
| Skipping objects | `GCS_KEY_PREFIX` / `GCS_KEY_SUFFIX` |
| No logs in Coralogix | Domain (`ingress.<CORALOGIX_DOMAIN>`), Explore time range vs `EdgeStartTimestamp` |
| Timeout | Raise memory/timeout; Logpush files can be large |
| Duplicate logs | Disable any other Cloudflare to Coralogix path for the same dataset |

## Local smoke test

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json
export CORALOGIX_SEND_YOUR_DATA_KEY=...
export CORALOGIX_DOMAIN=eu1.coralogix.com
python - <<'PY'
from main import process_event
print(process_event({"bucket": "YOUR-BUCKET", "name": "path/to/file.log.gz"}))
PY
```

# Teleport S3 Parquet to Coralogix

AWS Lambda that reads **Teleport Athena / External Audit Storage** parquet files from S3 and ships each audit event to the Coralogix Logs API.

Teleport writes Snappy-compressed parquet, partitioned by date:

```
s3://<bucket>/events/YYYY-MM-DD/<worker>-<timestamp>.parquet
```

Columns: `uid`, `session_id`, `event_type`, `user`, `event_time`, `event_data`  
`event_data` is the full audit event JSON (same fields you would see in Explore as `event`, `code`, `user`, `time`, ...).

```
S3 ObjectCreated (.parquet)
        |
        v
   Lambda (this function)
        |  parse parquet
        v
Coralogix Logs API  POST https://ingress.<domain>/logs/v1/bulk
        applicationName: teleport
        subsystemName:   audit
```

This path is for clusters that already land audit events in S3 as parquet. For **live** export from the Teleport API, use the Event Handler + OpenTelemetry guide under `docs/teleport-coralogix/` instead. Running both will duplicate events.

## Deploy with Terraform (recommended)

Full client steps (prerequisites, deployer IAM, image build, apply, verify, destroy): **[terraform/README.md](terraform/README.md)**.

```bash
cd "SIEM & SaaS/Teleport-S3-Parquet/terraform"
cp values.auto.tfvars.example values.auto.tfvars
# edit bucket, region, Coralogix domain
export TF_VAR_coralogix_api_key='your-send-your-data-key'
export AWS_PROFILE=your-profile
cd ..
chmod +x deploy.sh
./deploy.sh
```

Attach [terraform/deployer-iam-policy.json](terraform/deployer-iam-policy.json) to the user who runs Terraform. Replace `AWS_REGION`, `AWS_ACCOUNT_ID`, and `EVENTS_BUCKET`.

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CORALOGIX_SEND_YOUR_DATA_KEY` | Yes | ? | Send-Your-Data API key |
| `CORALOGIX_DOMAIN` | Yes | `coralogix.com` | e.g. `eu1.coralogix.com`, `eu2.coralogix.com`, `us1.coralogix.com`, `coralogix.in` |
| `CORALOGIX_APPLICATION_NAME` | No | `teleport` | Coralogix application |
| `CORALOGIX_SUBSYSTEM_NAME` | No | `audit` | Coralogix subsystem |
| `S3_KEY_PREFIX` | No | empty | Only process keys with this prefix (use `events/` so session recordings are ignored) |
| `S3_KEY_SUFFIX` | No | `.parquet` | Object suffix filter |
| `CORALOGIX_BATCH_SIZE` | No | `400` | Events per HTTP request |
| `CORALOGIX_TIMEOUT_SECONDS` | No | `60` | Ingest HTTP timeout |
| `CORALOGIX_MAX_RETRIES` | No | `4` | Retries on 429/5xx |
| `DRY_RUN` | No | `false` | Parse files but do not send |
| `LOG_LEVEL` | No | `INFO` | Lambda logging |

`CORALOGIX_PRIVATE_KEY`, `CORALOGIX_APPLICATION`, and `CORALOGIX_SUBSYSTEM` are accepted as aliases.

## Manual image build

`pyarrow` is too large for a typical zip package. Use a Lambda container image. Lambda requires a **single** `linux/amd64` manifest (not a Docker attestation index):

```bash
cd "snowbit-integrations/SIEM & SaaS/Teleport-S3-Parquet"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=eu-west-1
REPO=teleport-s3-parquet-coralogix

aws ecr create-repository --repository-name "$REPO" --region "$REGION" || true
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
  -t "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:latest" --push .
```

Create the function (if you are not using Terraform):

- Runtime: **Container image**
- Image: the URI you pushed
- Architecture: **x86_64**
- Memory: **1024 MB** (2048 MB if parquet files are large)
- Timeout: **5 minutes**
- Environment variables from `env.example`

Attach `iam-policy.json` (replace the bucket, prefix, and KMS key if the bucket uses SSE-KMS).

## S3 trigger

On the Teleport **events** bucket (not session recordings):

- Event type: `s3:ObjectCreated:*`
- Prefix: `events/` (adjust if your layout is `s3://bucket/<tenant-id>/YYYY-MM-DD/`)
- Suffix: `.parquet`

Lambda also unwraps **SNS** and **SQS** notifications that contain the same S3 event JSON, so you can put SQS in front for retries.

If the bucket is in another account, add a bucket policy allowing this function's role `s3:GetObject`, and use a cross-account trigger or SQS.

## SAM / CloudFormation

```bash
sam deploy \
  --template-file template.yaml \
  --stack-name teleport-s3-parquet-coralogix \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    TeleportEventsBucket=your-bucket \
    EventsPrefix=events/ \
    ImageUri=ACCOUNT.dkr.ecr.REGION.amazonaws.com/teleport-s3-parquet-coralogix:latest \
    CoralogixDomain=eu1.coralogix.com \
    CoralogixApiKey=YOUR_KEY
```

Note: the bucket must already exist. If SAM cannot attach the S3 notification (existing bucket with other notifications), add the trigger in the S3 console.

## Backfill existing files

The S3 trigger only fires for **new** objects. To ship history:

```bash
aws s3 ls s3://YOUR-BUCKET/events/ --recursive \
  | awk '{print $4}' \
  | grep '\.parquet$' \
  | while read -r key; do
      aws lambda invoke \
        --function-name teleport-s3-parquet-coralogix \
        --cli-binary-format raw-in-base64-out \
        --payload "{\"bucket\":\"YOUR-BUCKET\",\"key\":\"${key}\"}" \
        /tmp/out.json
    done
```

Or invoke with a captured S3 event from CloudWatch.

## Finding logs in Coralogix

Use the **event time stored in the parquet file**, not always "last 15 minutes":

```
applicationName:teleport AND subsystemName:audit
applicationName:teleport AND event:user.login
applicationName:teleport AND event:session.start
```

Each log `text` is the Teleport audit JSON. Fields such as `event`, `code`, `user`, `uid`, and `time` are available after JSON parsing.

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| Function never runs | S3 prefix/suffix filter, Lambda permission `lambda:InvokeFunction` from S3 |
| Image manifest not supported | Rebuild with `--provenance=false --sbom=false` |
| `Missing required environment variable` | `CORALOGIX_SEND_YOUR_DATA_KEY` |
| AccessDenied on GetObject | IAM + KMS decrypt if SSE-KMS |
| Skipping keys | `S3_KEY_PREFIX` / session-recording paths under `/sessions/` |
| No logs in Coralogix | Domain (`ingress.<CORALOGIX_DOMAIN>`), Explore time range vs `event_time` |
| Timeout | Raise memory/timeout; parquet batches can hold up to ~20k events |
| Duplicate logs | Disable Event Handler if this S3 path is the only source you want |

## Local smoke test

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export CORALOGIX_SEND_YOUR_DATA_KEY=...
export CORALOGIX_DOMAIN=eu1.coralogix.com
export AWS_PROFILE=...
python - <<'PY'
from lambda_function import lambda_handler
print(lambda_handler({"bucket": "YOUR-BUCKET", "key": "events/2026-09-17/example.parquet"}, None))
PY
```

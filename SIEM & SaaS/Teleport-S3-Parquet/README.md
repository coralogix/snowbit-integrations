# Teleport S3 Parquet to Coralogix

AWS Lambda that reads **Teleport External Audit Storage / Athena** parquet files from S3 and ships each audit event to the Coralogix Logs API.

Use this when the cluster **already** writes audit events to S3 as Snappy parquet. For live export from the Teleport API, use the Event Handler + OpenTelemetry guide under `docs/teleport-coralogix/` instead. **Do not run both** unless you want duplicate events.

Terraform does **not** create Teleport or the events bucket. Clients deploy the Lambda, a private ECR repository, IAM, and an optional S3 notification.

A printable client pack is in [docs/Teleport-S3-Parquet-Client-Architecture.pdf](docs/Teleport-S3-Parquet-Client-Architecture.pdf). Longer notes: [ARCHITECTURE.md](ARCHITECTURE.md) and [terraform/README.md](terraform/README.md).

---

## Architecture

```
Teleport cluster
  External Audit Storage / Athena
        |
        |  write Snappy parquet
        v
S3 events bucket   (already exists — not created by Terraform)
  s3://<bucket>/events/YYYY-MM-DD/<worker>-<timestamp>.parquet
        |
        |  s3:ObjectCreated:*   prefix events/   suffix .parquet
        v
AWS Lambda   package_type = Image   arch = x86_64
  1024 MB memory   300 s timeout   no VPC   no Lambda layers
  image: public.ecr.aws/lambda/python:3.12 + pyarrow + this handler
        |
        |  POST https://ingress.<CORALOGIX_DOMAIN>/logs/v1/bulk
        |  applicationName = teleport   subsystemName = audit
        v
Coralogix Logs  →  Explore
  Search by parquet event_time, not “last 15 minutes”
```

Parquet columns: `uid`, `session_id`, `event_type`, `user`, `event_time`, `event_data`.  
`event_data` is the full Teleport audit JSON (`event`, `code`, `user`, `time`, …).

The handler also unwraps SNS/SQS that wrap the same S3 JSON, and a direct invoke:

```json
{"bucket": "your-events-bucket", "key": "events/2026-09-11/file.parquet"}
```

The S3 trigger fires only for **new** objects. Existing files need a backfill invoke (below). Paths under `/sessions/` are skipped.

### Why a container image (not zip, not layers)

| Option | Limit | Verdict |
|--------|--------|---------|
| Lambda zip | 50 MB uploaded / 250 MB unzipped | pyarrow is too large |
| Lambda layer | Same unzipped cap; must match Python 3.12 + x86_64 | Do not use |
| **Container image** | Up to 10 GB | **Required** |

This integration attaches **no layers**. `pyarrow>=17` and `boto3>=1.34` are installed **inside** the image.

### Image that is required

```dockerfile
FROM public.ecr.aws/lambda/python:3.12
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r requirements.txt
COPY lambda_function.py ${LAMBDA_TASK_ROOT}/
CMD ["lambda_function.lambda_handler"]
```

| Requirement | Value | Why |
|-------------|--------|-----|
| Base | `public.ecr.aws/lambda/python:3.12` | Official Lambda RIC + Python 3.12 |
| Platform | `linux/amd64` (x86_64) | Matches `architectures = ["x86_64"]`. arm64 will not run |
| Manifest | Single image, not a Docker index | Lambda rejects attestation/SBOM indexes |
| Build | `docker buildx --platform linux/amd64 --provenance=false --sbom=false --push` | Required on Apple silicon and Docker Desktop |
| Store | Private ECR, **same account and region** as the function | Lambda will not run from Docker Hub or `public.ecr.aws` |

Image filesystem: (1) AWS base — Amazon Linux, Python 3.12, RIC. (2) pip — pyarrow, boto3. (3) `lambda_function.py`.

### What Terraform creates

| Created | Not created |
|---------|-------------|
| ECR repository (unless you set `image_uri`) | Teleport cluster |
| IAM role: GetObject on `events/*`, ListBucket, logs, optional KMS | Events S3 bucket |
| Lambda (Image, x86_64, 1024 MB, 300 s) | Session-recording pipeline |
| `lambda:AddPermission` + optional S3 notification | Coralogix parsers |

`create_s3_notification = true` **replaces** the entire bucket notification config. Turn it off if other triggers already exist.

IAM is split: **deployer** (`terraform/deployer-iam-policy.json`) vs **runtime** role (least privilege at invoke time).

---

## Deploy (Terraform)

### 1. Prerequisites

| Item | Notes |
|------|--------|
| Terraform >= 1.5 | `terraform version` |
| AWS CLI + credentials | Same account and **region** as the events bucket |
| Docker | Must build **linux/amd64** (also on Apple silicon) |
| Existing S3 events bucket | Teleport parquet, not session recordings |
| Coralogix Send-Your-Data key | Data Flow → API Keys |
| Coralogix domain | Team domain only: `eu1.coralogix.com`, `eu2.coralogix.com`, `us1.coralogix.com`, `coralogix.in`, … |
| Deployer IAM | Attach [terraform/deployer-iam-policy.json](terraform/deployer-iam-policy.json). Replace `AWS_REGION`, `AWS_ACCOUNT_ID`, `EVENTS_BUCKET` |

If the bucket uses SSE-KMS, add `kms:Decrypt` / `DescribeKey` / `GenerateDataKey` on that key and set `kms_key_arn`.

### 2. Configure

```bash
cd "SIEM & SaaS/Teleport-S3-Parquet/terraform"
cp values.auto.tfvars.example values.auto.tfvars
```

Edit `values.auto.tfvars`:

- `aws_region` — **same region as the events bucket**
- `events_bucket` — existing bucket name
- `events_prefix` — `events/` unless keys use another prefix (for example a tenant id)
- `coralogix_domain` — team domain, **not** `ingress.`
- `create_s3_notification` — `true` only if this bucket has **no other** notifications
- `manage_log_group` — leave `false` unless the deployer can call `logs:DescribeLogGroups`

Do **not** put the API key in the file. Export it:

```bash
export AWS_PROFILE=your-profile
export TF_VAR_coralogix_api_key='your-send-your-data-key'
```

### 3. Apply

```bash
cd "SIEM & SaaS/Teleport-S3-Parquet"
chmod +x deploy.sh
./deploy.sh
```

`deploy.sh` runs `terraform init` → creates ECR if needed → `docker buildx` linux/amd64 **without** attestations → `terraform apply`.

Manual equivalent is in [terraform/README.md](terraform/README.md). If you already have an image in ECR, set `image_uri` and skip the build.

### 4. Verify

The S3 trigger fires only for **new** objects.

```bash
aws s3 cp ./sample.parquet s3://YOUR-BUCKET/events/$(date -u +%Y-%m-%d)/sample.parquet

aws lambda invoke \
  --function-name teleport-s3-parquet-coralogix \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucket":"YOUR-BUCKET","key":"events/YYYY-MM-DD/sample.parquet"}' \
  /tmp/out.json && cat /tmp/out.json
```

Success: `{"ok":true,"files":1,"events":N,"sent":N}`.

Explore (use **parquet event time**, not “last 15 minutes”):

```
applicationName:teleport AND subsystemName:audit
applicationName:teleport AND event:user.login
```

### 5. Backfill existing files

```bash
aws s3 ls s3://YOUR-BUCKET/events/ --recursive \
  | awk '{print $4}' | grep '\.parquet$' \
  | while read -r key; do
      aws lambda invoke \
        --function-name teleport-s3-parquet-coralogix \
        --cli-binary-format raw-in-base64-out \
        --payload "{\"bucket\":\"YOUR-BUCKET\",\"key\":\"${key}\"}" \
        /tmp/out.json
    done
```

### 6. Destroy

```bash
cd terraform
terraform destroy
```

Use the same vars / `TF_VAR_coralogix_api_key`. ECR uses `force_delete`. The events bucket is **not** deleted.

---

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CORALOGIX_SEND_YOUR_DATA_KEY` | Yes | — | Send-Your-Data API key |
| `CORALOGIX_DOMAIN` | Yes | `coralogix.com` | e.g. `eu1.coralogix.com` |
| `CORALOGIX_APPLICATION_NAME` | No | `teleport` | Coralogix application |
| `CORALOGIX_SUBSYSTEM_NAME` | No | `audit` | Coralogix subsystem |
| `S3_KEY_PREFIX` | No | empty / `events/` | Ignore session recordings |
| `S3_KEY_SUFFIX` | No | `.parquet` | Object suffix |
| `CORALOGIX_BATCH_SIZE` | No | `400` | Events per HTTP request |
| `CORALOGIX_TIMEOUT_SECONDS` | No | `60` | Ingest HTTP timeout |
| `CORALOGIX_MAX_RETRIES` | No | `4` | Retries on 429/5xx |
| `DRY_RUN` | No | `false` | Parse only, do not POST |
| `LOG_LEVEL` | No | `INFO` | Lambda logging |

`CORALOGIX_PRIVATE_KEY`, `CORALOGIX_APPLICATION`, and `CORALOGIX_SUBSYSTEM` are accepted as aliases.

---

## Manual image build (no Terraform)

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

Create the function: package **Container image**, arch **x86_64**, memory **1024 MB**, timeout **5 minutes**, env from `env.example`. Attach `iam-policy.json`.

S3 trigger on the **events** bucket: `s3:ObjectCreated:*`, prefix `events/`, suffix `.parquet`.

SAM: see `template.yaml`. The bucket must already exist.

---

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| Function never runs | Prefix/suffix, `lambda:InvokeFunction` from S3, bucket region vs `aws_region` |
| Image manifest not supported | Rebuild with `--provenance=false --sbom=false` and `linux/amd64` |
| `Missing required environment variable` | `CORALOGIX_SEND_YOUR_DATA_KEY` |
| AccessDenied on GetObject | Runtime IAM + KMS decrypt if SSE-KMS |
| `logs:DescribeLogGroups` AccessDenied | Keep `manage_log_group = false` |
| Skipping keys | `S3_KEY_PREFIX` / paths under `/sessions/` |
| Empty Explore | Domain (`ingress.<CORALOGIX_DOMAIN>`), time range vs parquet `event_time` |
| Timeout | Raise memory (also CPU) and timeout |
| Duplicate logs | Disable Event Handler if this S3 path is the only source |

---

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

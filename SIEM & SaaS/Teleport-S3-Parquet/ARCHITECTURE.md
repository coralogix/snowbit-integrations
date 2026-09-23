# Architecture: Teleport S3 parquet to Coralogix

This stack does **not** create Teleport or the events bucket. Teleport External Audit Storage / Athena already writes Snappy-compressed parquet. Terraform deploys a **container-image Lambda** that reads new objects and POSTs each audit event to Coralogix.

## End-to-end

```
Teleport cluster
  External Audit Storage
        |
        |  write parquet
        v
S3 events bucket
  s3://<bucket>/events/YYYY-MM-DD/<file>.parquet
        |
        |  s3:ObjectCreated:*  (prefix events/, suffix .parquet)
        v
AWS Lambda  (x86_64, package_type = Image)
  1024 MB, 300 s timeout
  image: public.ecr.aws/lambda/python:3.12 + pyarrow + handler
        |
        |  POST https://ingress.<CORALOGIX_DOMAIN>/logs/v1/bulk
        |  applicationName=teleport  subsystemName=audit
        v
Coralogix Logs  -->  Explore (use parquet event_time, not "last 15 minutes")
```

Optional wrappers the handler already understands: SNS or SQS that contain the same S3 event JSON. Direct invoke for backfill:

```json
{"bucket": "your-events-bucket", "key": "events/2026-09-11/file.parquet"}
```

Do not also run the Teleport Event Handler / OpenTelemetry export unless you want duplicate events.

## Why a container image (not zip, not layers)

| Option | Limit / issue | Verdict |
|--------|----------------|---------|
| Lambda zip | 50 MB uploaded, 250 MB unzipped | pyarrow wheel is ~50 MB for manylinux x86_64; zip is not reliable |
| Lambda layer | Same 250 MB unzipped cap; must match Python 3.12 + x86_64 | Extra moving part, same size problem |
| **Container image** | 10 GB; native `pip install` on the AWS base | **Required** |

This integration attaches **no Lambda layers**. `pyarrow` and `boto3` are installed **inside the image**.

## Image that is required

```dockerfile
FROM public.ecr.aws/lambda/python:3.12
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r requirements.txt
COPY lambda_function.py ${LAMBDA_TASK_ROOT}/
CMD ["lambda_function.lambda_handler"]
```

| Requirement | Value | Why |
|-------------|--------|-----|
| Base | `public.ecr.aws/lambda/python:3.12` | Official Lambda Runtime Interface Client + Python 3.12 |
| OS/arch | `linux/amd64` | Terraform sets `architectures = ["x86_64"]`. arm64 images fail at runtime |
| Manifest | **Single** image, not a Docker index | Lambda rejects attestation/SBOM indexes (`image manifest is not supported`) |
| Build flags | `--platform linux/amd64 --provenance=false --sbom=false --push` | Even on Apple silicon |
| Entrypoint | `lambda_function.lambda_handler` | Matches `CMD` |

### Image layers (filesystem)

1. **AWS base** — Amazon Linux, Python 3.12, Lambda RIC. This is what the Lambda service boots.
2. **pip layer** — `pyarrow>=17` (Snappy parquet) and `boto3>=1.34` (S3 GetObject). boto3 is also on the base image; pinning it in requirements keeps local/dev aligned.
3. **App layer** — `lambda_function.py` only.

Store the image in **ECR** in the same account/region as the function (`teleport-s3-parquet-coralogix:latest` unless you pass `image_uri`).

## Lambda architecture (the function)

| Setting | Default | Notes |
|---------|---------|--------|
| Package | Image | Not Zip |
| Arch | x86_64 | Must match the image |
| Memory | 1024 MB | 2048 MB if parquet files are large (more CPU too) |
| Timeout | 300 s | A file can hold many thousands of events |
| Env | See below | API key is sensitive; prefer `TF_VAR_coralogix_api_key` |

**Handler flow**

1. Extract bucket/key from S3 / SNS / SQS / direct payload.
2. Skip if suffix is not `.parquet`, prefix does not match `events/`, or path contains `/sessions/`.
3. `s3.get_object` → `pyarrow.parquet.read_table`.
4. Map columns `uid`, `session_id`, `event_type`, `user`, `event_time`, `event_data` (JSON).
5. POST batches of 400 to Coralogix; retry on 429/5xx.

Parquet columns Teleport writes: `uid`, `session_id`, `event_type`, `user`, `event_time`, `event_data`.

## AWS pieces Terraform creates

```
Deployer (IAM user/role)                 Runtime
  terraform + docker push                  Lambda execution role
        |                                         |
        v                                         v
  ECR repo  -->  image:latest            s3:GetObject events/*
  IAM role + policy                      s3:ListBucket (prefix)
  Lambda function                        logs:CreateLogStream/PutLogEvents
  lambda permission (s3 principal)       optional kms:Decrypt
  optional S3 bucket notification
```

**Not created:** Teleport, the events bucket, session-recording pipelines, Coralogix parsers.

`create_s3_notification = true` **replaces** the entire bucket notification config. Turn it off if other triggers already exist.

`manage_log_group = false` (default) lets Lambda create `/aws/lambda/<name>` on first invoke. Set true only if the deployer can call `logs:DescribeLogGroups`.

## Requirements to deploy

- Terraform >= 1.5, AWS CLI, Docker (linux/amd64 build)
- Existing Teleport events bucket in the **same region** as `aws_region`
- Coralogix Send-Your-Data key and matching domain (`eu1.coralogix.com`, …)
- Deployer IAM from `terraform/deployer-iam-policy.json`
- Network egress from Lambda to `ingress.<domain>` (no VPC in this module)

## Finding logs

Explore query: `applicationName:teleport AND subsystemName:audit`

Use the **event time inside the parquet** (`event_time` / `time`), not “last 15 minutes”, unless the file is new.

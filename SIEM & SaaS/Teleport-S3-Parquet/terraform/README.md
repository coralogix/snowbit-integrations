# Terraform: Teleport S3 parquet to Coralogix

Deploys an AWS Lambda **container image** that reads Teleport External Audit Storage / Athena **parquet** files from S3 and POSTs each audit event to the Coralogix Logs API.

Terraform does **not** create the Teleport bucket. Use the bucket your cluster already writes to.

```
s3://<events-bucket>/events/YYYY-MM-DD/<file>.parquet
        |
        v  s3:ObjectCreated:*
   Lambda (linux/amd64 image)
        |
        v
POST https://ingress.<CORALOGIX_DOMAIN>/logs/v1/bulk
        applicationName: teleport
        subsystemName:   audit
```

Do not run this together with the Teleport Event Handler / OpenTelemetry export unless you want duplicate events.

## What you need

| Item | Notes |
|------|--------|
| Terraform >= 1.5 | `terraform version` |
| AWS CLI + credentials | Same account/region as the events bucket |
| Docker Desktop (or equivalent) | Must build **linux/amd64**. Required on Apple silicon too |
| Existing S3 bucket | Teleport parquet events (not session recordings) |
| Coralogix Send-Your-Data API key | Data Flow → API Keys |
| Coralogix domain | Must match the team: `eu1.coralogix.com`, `eu2.coralogix.com`, `us1.coralogix.com`, `coralogix.in`, … |

`pyarrow` does not fit in a Lambda zip. This integration is **container image only**.

## 1. IAM for the deploying user

Attach [deployer-iam-policy.json](deployer-iam-policy.json) to the IAM user or role that runs Terraform and `docker push`. Replace:

- `AWS_REGION` — region of the bucket and Lambda (example: `eu-west-1`)
- `AWS_ACCOUNT_ID` — 12-digit account id
- `EVENTS_BUCKET` — Teleport events bucket name
- Function / ECR / role names if you change `function_name` or `ecr_repository_name`

`logs:DescribeLogGroups` is on `*` because that API does not accept a single log-group ARN. Optional: omit `s3:PutObject` if you will not upload test files; omit `s3:PutBucketNotification` if you set `create_s3_notification = false`.

If the bucket uses SSE-KMS, add `kms:Decrypt`, `kms:DescribeKey`, and `kms:GenerateDataKey` on that key, and set `kms_key_arn` in Terraform.

## 2. Configure

From the repository root:

```bash
cd "SIEM & SaaS/Teleport-S3-Parquet/terraform"
cp values.auto.tfvars.example values.auto.tfvars
```

Edit `values.auto.tfvars`:

- `aws_region` — **same region as `events_bucket`**
- `events_bucket` — existing bucket
- `events_prefix` — `events/` unless your keys use another prefix (for example a tenant id)
- `coralogix_domain` — team domain, not `ingress.`
- `create_s3_notification` — `true` only if this bucket has **no other** S3 notifications. A PutBucketNotification **replaces** the entire notification config
- `manage_log_group` — `false` (default) lets Lambda create the log group. Set `true` if you want Terraform to set 14-day retention

Do **not** put the API key in the file (it is gitignored, but still easy to leak). Export it:

```bash
export AWS_PROFILE=your-profile
export TF_VAR_coralogix_api_key='your-send-your-data-key'
```

## 3. Deploy

One command from `SIEM & SaaS/Teleport-S3-Parquet`:

```bash
chmod +x deploy.sh
./deploy.sh
```

The script: `terraform init` → create ECR if needed → `docker buildx` linux/amd64 (no attestations; Lambda rejects image indexes) → `terraform apply`.

### Manual steps (same result)

```bash
cd terraform
terraform init
terraform apply -target=aws_ecr_repository.this

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO=$(terraform output -raw ecr_repository_url)
REGION=$(echo "$REPO" | cut -d. -f4)

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
  -t "${REPO}:latest" --push ..

terraform apply
```

If you already have an image in ECR, set `image_uri` and skip the ECR target and push.

## 4. Verify

The S3 trigger fires only for **new** objects. Upload a parquet file or invoke:

```bash
aws s3 cp ./sample.parquet s3://YOUR-BUCKET/events/$(date -u +%Y-%m-%d)/sample.parquet

aws lambda invoke \
  --function-name teleport-s3-parquet-coralogix \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucket":"YOUR-BUCKET","key":"events/YYYY-MM-DD/sample.parquet"}' \
  /tmp/out.json && cat /tmp/out.json
```

Success looks like `{"ok":true,"files":1,"events":N,"sent":N}`.

In Coralogix Explore, search with the **event time inside the parquet** (often not “last 15 minutes”):

```
applicationName:teleport AND subsystemName:audit
```

## Variables

| Name | Required | Default | Notes |
|------|----------|---------|--------|
| `events_bucket` | yes | — | Existing bucket |
| `coralogix_api_key` | yes | — | `TF_VAR_coralogix_api_key` |
| `aws_region` | no | `eu-west-1` | Must match the bucket region for the S3 trigger |
| `coralogix_domain` | no | `eu1.coralogix.com` | Team domain |
| `coralogix_application_name` | no | `teleport` | |
| `coralogix_subsystem_name` | no | `audit` | |
| `events_prefix` | no | `events/` | Skip session recordings |
| `events_suffix` | no | `.parquet` | |
| `function_name` | no | `teleport-s3-parquet-coralogix` | Must match deployer IAM ARNs |
| `image_uri` | no | empty | Empty = create ECR |
| `create_s3_notification` | no | `true` | Replaces bucket notifications |
| `manage_log_group` | no | `false` | Needs `logs:DescribeLogGroups` if true |
| `kms_key_arn` | no | empty | SSE-KMS buckets |
| `dry_run` | no | `false` | Parse only, do not send |

## Backfill

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
      cat /tmp/out.json
    done
```

## Troubleshooting

| Symptom | What to do |
|---------|------------|
| `The image manifest ... is not supported` | Rebuild with `docker buildx build --platform linux/amd64 --provenance=false --sbom=false --push` |
| `logs:DescribeLogGroups` AccessDenied | Keep `manage_log_group = false`, or add DescribeLogGroups on `*` |
| `ecr:CreateRepository` AccessDenied | Attach `deployer-iam-policy.json` |
| Function never runs | Prefix/suffix, `lambda:AddPermission`, bucket region vs `aws_region` |
| AccessDenied on GetObject | Lambda role + optional KMS |
| Empty Explore | Wrong team/domain, or time range is not the parquet `event_time` |
| Duplicate events | Disable Teleport Event Handler if S3 is the only source |

## Destroy

```bash
cd terraform
terraform destroy
```

Pass the same `-var` / `values.auto.tfvars` / `TF_VAR_coralogix_api_key` you used to apply. ECR uses `force_delete`. The events bucket is not deleted.

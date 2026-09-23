#!/usr/bin/env bash
# Create ECR (if needed), build linux/amd64 image, push, terraform apply.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${ROOT}/terraform"

if [[ ! -f "${TF_DIR}/values.auto.tfvars" ]]; then
  echo "Copy terraform/values.auto.tfvars.example to terraform/values.auto.tfvars and fill it in." >&2
  exit 1
fi

if [[ -z "${TF_VAR_coralogix_api_key:-}" ]]; then
  echo "Export TF_VAR_coralogix_api_key before running this script." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to build the Lambda image (pyarrow does not fit in a zip)." >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required." >&2
  exit 1
fi

cd "${TF_DIR}"
terraform init -input=false

if terraform output -raw ecr_repository_url >/dev/null 2>&1; then
  REPO_URL="$(terraform output -raw ecr_repository_url)"
else
  terraform apply -input=false -auto-approve -target=aws_ecr_repository.this
  REPO_URL="$(terraform output -raw ecr_repository_url)"
fi

if [[ -z "${REPO_URL}" || "${REPO_URL}" == "null" ]]; then
  echo "image_uri is set; skipping ECR push and applying Terraform."
  terraform apply -input=false -auto-approve
  exit 0
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGION="$(echo "${REPO_URL}" | cut -d. -f4)"

aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
  -t "${REPO_URL}:latest" --push "${ROOT}"

terraform apply -input=false -auto-approve
echo "Deployed. Function: $(terraform output -raw function_name)"

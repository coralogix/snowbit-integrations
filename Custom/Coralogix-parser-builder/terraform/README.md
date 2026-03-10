# Coralogix Parser - Terraform

Creates the OTEL Linux secure & cron parser in Coralogix.

## Prerequisites

- Terraform >= 1.3
- Coralogix API key with PARSINGRULES role

## Usage

```bash
cd terraform

# Option 1: Use environment variable
export CORALOGIX_API_KEY="your-api-key"
terraform init
terraform plan
terraform apply

# Option 2: Use tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your API key
terraform init
terraform apply -var-file=terraform.tfvars

# Option 3: Pass on command line
terraform apply -var="coralogix_api_key=your-key" -var="coralogix_endpoint=cx498.coralogix.com"
```

## Output

The parser rule group will be created in your Coralogix account. View it under **Data Flow → Parsing**.

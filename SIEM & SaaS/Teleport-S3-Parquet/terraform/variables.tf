variable "aws_region" {
  type        = string
  description = "AWS region for ECR, Lambda, and IAM."
  default     = "eu-west-1"
}

variable "events_bucket" {
  type        = string
  description = "Existing S3 bucket that already holds Teleport parquet audit events. Terraform does not create this bucket."
}

variable "events_prefix" {
  type        = string
  description = "S3 key prefix for audit parquet objects. Use events/ so session recordings are ignored."
  default     = "events/"
}

variable "events_suffix" {
  type        = string
  description = "S3 key suffix filter."
  default     = ".parquet"
}

variable "function_name" {
  type        = string
  description = "Lambda function name."
  default     = "teleport-s3-parquet-coralogix"
}

variable "memory_size" {
  type        = number
  description = "Lambda memory in MB. Raise to 2048 if parquet files are large."
  default     = 1024
}

variable "timeout" {
  type        = number
  description = "Lambda timeout in seconds."
  default     = 300
}

variable "manage_log_group" {
  type        = bool
  description = "Create the CloudWatch log group in Terraform. Requires logs:DescribeLogGroups. If false, Lambda creates the group on first invoke."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention when manage_log_group is true."
  default     = 14
}

variable "coralogix_domain" {
  type        = string
  description = "Coralogix domain, for example eu1.coralogix.com, us1.coralogix.com, or coralogix.in."
  default     = "eu1.coralogix.com"
}

variable "coralogix_api_key" {
  type        = string
  description = "Coralogix Send-Your-Data API key. Prefer TF_VAR_coralogix_api_key instead of committing this value."
  sensitive   = true
}

variable "coralogix_application_name" {
  type        = string
  description = "Coralogix applicationName."
  default     = "teleport"
}

variable "coralogix_subsystem_name" {
  type        = string
  description = "Coralogix subsystemName."
  default     = "audit"
}

variable "coralogix_batch_size" {
  type    = number
  default = 400
}

variable "dry_run" {
  type        = bool
  description = "Parse parquet but do not send to Coralogix."
  default     = false
}

variable "image_uri" {
  type        = string
  description = "Full Lambda image URI (ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:TAG). Leave empty to create an ECR repository and use repository_url:image_tag after you push."
  default     = ""
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR repository created when image_uri is empty."
  default     = "teleport-s3-parquet-coralogix"
}

variable "image_tag" {
  type        = string
  description = "Tag to use with the Terraform-managed ECR repository."
  default     = "latest"
}

variable "create_s3_notification" {
  type        = bool
  description = "Attach s3:ObjectCreated:* on the events bucket. This replaces the bucket notification configuration. Disable if the bucket already has other notifications and add the trigger in the S3 console instead."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Optional KMS key ARN if the events bucket uses SSE-KMS."
  default     = ""
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}

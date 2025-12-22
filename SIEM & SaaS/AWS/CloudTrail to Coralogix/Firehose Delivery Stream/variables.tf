variable "privateKey" {
  description = "The 'send your data' API key from Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}-(\\w{4}-){3}\\w{12}$", var.privateKey))
    error_message = "The PrivateKey should be valid UUID string"
  }
}
variable "coralogix_region" {
  description = "Enter the Coralogix account region [in lower-case letters]: \n- eu1\n- eu2\n- ap1\n- ap2\n- ap3\n- us1\n- us2"
}
variable "cx_region_map" {
  type    = map(string)
  default = {
    eu1 = "https://ingress.eu1.coralogix.com/aws/firehose"
    eu2 = "https://ingress.eu2.coralogix.com/aws/firehose"
    ap1 = "https://ingress.ap1.coralogix.com/aws/firehose"
    ap2 = "https://ingress.ap2.coralogix.com/aws/firehose"
    ap3 = "https://ingress.ap3.coralogix.com/aws/firehose"
    us1 = "https://ingress.us1.coralogix.com/aws/firehose"
    us2 = "https://ingress.us2.coralogix.com/aws/firehose"
  }
}
variable "output_format" {
  description = "The output format of the cloudwatch metric stream: 'json' or 'opentelemetry0.7'"
  type        = string
  default     = "json"
}
variable "integration_type" {
  description = "The integration type of the firehose delivery stream: 'CloudWatch_Metrics_JSON', 'CloudWatch_Metrics_OpenTelemetry070' or 'CloudWatch_CloudTrail'"
  type        = string
  default     = "CloudWatch_CloudTrail"
}
variable "application_name" {
  description = "The application name for the log group in Coralogix"
  type        = string
}
variable "subsystemName" {
  description = "The sub-system name for the log group in Coralogix"
  type        = string
}
variable "log_group_name" {
  type        = string
  description = "The existing log group that saves the CloudTrail logs in CloudWatch"
}
variable "firehose_stream" {
  description = "The AWS Kinesis firehose delivery stream name that will be created"
  type        = string
  default     = "coralogix-firehose"
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "s3_bucket_versioning" {
  type = string
  validation {
    condition     = can(regex("^(Disabled|Enabled|Suspended)$", var.s3_bucket_versioning))
    error_message = "Versioning can either be 'Enabled', 'Disabled' or 'Suspended'"
  }
}
variable "s3_bucket_acl" {
  type = string
  validation {
    condition     = var.s3_bucket_acl == "private" || var.s3_bucket_acl == "public-read" || var.s3_bucket_acl == "public-read-write" || var.s3_bucket_acl == "authenticated-read" || var.s3_bucket_acl == "aws-exec-read" || var.s3_bucket_acl == "log-delivery-write"
    error_message = "Can either be 'private', 'public-read', 'public-read-write', 'authenticated-read', 'aws-exec-read' or 'log-delivery-write'"
  }
}
variable "s3_bucket_encryption" {
  type    = bool
  default = true
}
variable "log_group_kms_key_id" {
  type    = string
  default = ""
}
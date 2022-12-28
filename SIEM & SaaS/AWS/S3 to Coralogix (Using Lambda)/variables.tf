## ----- Lambda Function ----- ##
variable "function_name" {
  type        = string
  description = "The Lambda function name in the AWS account"
}
variable "architecture" {
  description = "Lambda function architecture"
  type        = string
  default     = "x86_64"
}
variable "memory_size" {
  description = "Lambda function memory limit"
  type        = number
  default     = 1024
}
variable "timeout" {
  description = "Lambda function timeout limit"
  type        = number
  default     = 300
}
variable "newline_pattern" {
  description = "The pattern for lines splitting"
  type        = string
  default     = "(?:\\r\\n|\\r|\\n)"
}
variable "blocking_pattern" {
  description = "The pattern for lines blocking"
  type        = string
  default     = ""
}
variable "buffer_size" {
  description = "Coralogix logger buffer size"
  type        = number
  default     = 134217728
}
variable "sampling_rate" {
  description = "Send messages with specific rate"
  type        = number
  default     = 1
}
variable "debug" {
  description = "Coralogix logger debug mode"
  type        = bool
  default     = false
}
variable "s3_key_prefix" {
  description = "The S3 path prefix to watch"
  type        = string
  default     = null
}
variable "s3_key_suffix" {
  description = "The S3 path suffix to watch"
  type        = string
  default     = null
}
variable "kms_id_for_s3" {
  type        = string
  description = "The ARN for the KMS used for the encryption"
}
variable "kms_id_for_lambda_log_group" {
  type = string
}

## ---- Coralogix Account ---- ##
variable "private_key" {
  description = "The Coralogix private key which is used to validate your authenticity"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}-(\\w{4}-){3}\\w{12}$", var.private_key))
    error_message = "The PrivateKey should be valid UUID string"
  }
}
variable "application_name" {
  description = "The name of your application"
  type        = string
}
variable "subsystem_name" {
  description = "The subsystem name of your application"
  type        = string
}
variable "coralogix_region" {
  description = "The Coralogix location region, possible options are [Europe, Europe2, India, Singapore, US]"
  type        = string
  default     = "Europe"
}

## --------- General --------- ##
variable "s3-bucket" {
  type        = string
  description = "The s3 that saves the data you wish to send to Coralogix"
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
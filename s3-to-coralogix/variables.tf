variable "package_name" {
  description = "The name of the package to use for the function"
  type        = string
  default     = "s3"
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
variable "coralogix_region" {
  description = "The Coralogix location region, possible options are [Europe, Europe2, India, Singapore, US]"
  type        = string
  default     = "Europe"
}
variable "private_key" {
  description = "The Coralogix private key which is used to validate your authenticity"
  type        = string
  sensitive   = true
  validation {
    condition = can(regex("[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}", var.private_key))
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
variable "kms_arn" {
  type = string
  description = "The ARN for the KMS used for the encryption"
}
variable "guardduty-s3-bucket" {
  type = string
  description = "The s3 that saves the data for GuardDuty"
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

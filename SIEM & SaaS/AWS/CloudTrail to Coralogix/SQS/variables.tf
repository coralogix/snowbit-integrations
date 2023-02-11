variable "privateKey" {
  description = "The 'send your data' API key from Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}-(\\w{4}-){3}\\w{12}$", var.privateKey))
    error_message = "The PrivateKey should be valid UUID string"
  }
}
variable "application_name" {
  description = "The application name in Coralogix"
  type        = string
}
variable "subsystemName" {
  description = "The sub-system name in Coralogix"
  type        = string
}
variable "coralogix_region" {
  description = "Enter the Coralogix account region. Can be 'US', 'Singapore', 'Europe', 'Europe2' or 'India'"
}
variable "cx_region_map" {
  type    = map(string)
  default = {
    Europe    = "https://api.coralogix.com/api/v1/logs"
    Europe2   = "https://api.eu2.coralogix.com/api/v1/logs"
    India     = "https://api.app.coralogix.in/api/v1/logs"
    Singapore = "https://api.coralogixsg.com/api/v1/logs"
    US        = "https://api.coralogix.us/api/v1/logs"
  }
}
variable "function_name" {
  type = string
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "sqs_queue_name" {
  type = string
}
variable "s3_bucket_to_monitor" {
  type = string
}
variable "privetKey" {
  description = "The 'send your data' API key from Coralogix account"
  sensitive   = true
}
variable "coralogix_region" {
  description = "Enter the Coralogix account region [in lower-case letters]: \n- us\n- singapore\n- ireland\n- india\n- stockholm"
}
variable "cx_region_map" {
  type = map(string)
  default = {
    Europe = "https://firehose-ingress.coralogix.com/firehose"
    Europe2 = "https://firehose-ingress.eu2.coralogix.com/firehose"
    India = "https://firehose-ingress.coralogix.in/firehose"
    Singapore = "https://firehose-ingress.coralogixsg.com/firehose"
    US = "https://firehose-ingress.coralogix.us/firehose"
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
variable "log_group" {
  type        = string
  description = "The log group to to be created that will save the firehose execution logs"
}
variable "log_group_name" {
  type        = string
  description = "The existing log group that saves the CloudTrail logs in CloudWatch"
}
variable "firehose_stream" {
  description = "The AWS Kinesis firehose delivery stream name that will be created"
  type        = string
  default     = "firehose-stream"
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
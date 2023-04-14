variable "custom_event_bus_name" {
  type = string
}
variable "coralogix_endpoint_map" {
  type    = map(string)
  default = {
    Europe    = "https://aws-events.coralogix.com/aws/event"
    Europe2   = "https://aws-events.eu2.coralogix.com/aws/event"
    India     = "https://aws-events.coralogix.in/aws/event"
    Singapore = "https://aws-events.coralogixsg.com/aws/event"
    US        = "https://aws-events.coralogix.us/aws/event"
  }
}
variable "coralogix_endpoint" {
  type = string
  validation {
    condition     = can(regex("^Europe|Europe2|India|Singapore|US$", var.coralogix_endpoint))
    error_message = "Invalid Coralogix endpoint"
  }
}
variable "application_name" {
  type = string
}
variable "subsystem_name" {
  type = string
}
variable "private_key" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}", var.private_key))
    error_message = "Invalid private key - expected a valid UUID"
  }
}
variable "additional_tags" {
  type = map(string)
}
variable "event_pattern" {
  type = set(string)
}
locals {
  event_pattern_map = {
    inspector_findings = <<EOF
{
  "source": ["aws.inspector2"],
  "detail-type": ["Inspector2 Finding"]
}
EOF
    guardDuty_findings = <<EOF
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"]
}
EOF
    auth0              = <<EOF
{
  "source": [{
    "prefix": "aws.partner/auth0.com"
  }]
}
EOF
    ecr_image_scan = <<EOF
{
  "source": ["aws.ecr"],
  "detail-type": ["ECR Image Scan"]
}
EOF
  }
}
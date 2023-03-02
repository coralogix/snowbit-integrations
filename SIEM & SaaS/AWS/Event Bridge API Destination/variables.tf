variable "event_api_destination_name" {
  type = string
}
variable "event_connection_name" {
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
}
variable "additional_tags" {
  type = map(string)
}
variable "event_pattern_map" {
  type    = map(string)
  default = {
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
  }
}
variable "event_pattern" {
  type = string
  validation {
    condition     = can(regex("^(inspector|guardDuty)_findings$", var.event_pattern))
    error_message = "Invalid event pattern"
  }
}
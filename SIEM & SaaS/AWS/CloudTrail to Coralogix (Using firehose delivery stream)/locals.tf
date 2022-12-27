locals {
    endpoint_url = {
      "us" = {
        url = "https://firehose-ingress.coralogix.us/firehose"
      }
      "singapore" = {
        url = "https://firehose-ingress.coralogixsg.com/firehose"
      }
      "ireland" = {
        url = "https://firehose-ingress.coralogix.com/firehose"
      }
      "india" = {
        url = "https://firehose-ingress.coralogix.in/firehose"
      }
      "stockholm" = {
        url = "https://firehose-ingress.eu2.coralogix.com/firehose"
      }
    }
  tags = {
    terraform-module         = "kinesis-firehose-to-coralogix"
    terraform-module-version = "v0.0.1"
    managed-by               = "coralogix-terraform"
  }
  application_name = var.application_name == "" ? "snowbit-cloudtrail" : var.application_name
  subsystem_name   = var.subsystemName == "" ? "snowbit-cloudtrail" : var.subsystemName
}

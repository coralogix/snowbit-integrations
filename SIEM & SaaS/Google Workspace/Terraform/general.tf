# Variables --->
variable "instance_cloud_provider" {
  type = string
  validation {
    condition = var.instance_cloud_provider == "AWS" || var.instance_cloud_provider == "GCP"
    error_message = "Invalid provided chosen."
  }
}
variable "filebeat_certificates_map_url" {
  type    = map(string)
  default = {
    Europe    = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    India     = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    US        = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
    Singapore = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
  }
}
variable "filebeat_certificate_map_file_name" {
  type    = map(string)
  default = {
    Europe    = "Coralogix-EU.crt"
    India     = "Coralogix-IN.pem"
    US        = "AmazonRootCA1.pem"
    Singapore = "AmazonRootCA1.pem"
  }
}
variable "logstash_map" {
  type    = map(string)
  default = {
    Europe    = "logstashserver.coralogix.com"
    India     = "logstash.app.coralogix.in"
    US        = "logstashserver.coralogix.us"
    Singapore = "logstashserver.coralogixsg.com"
  }
}
variable "coralogix_domain" {
  type    = string
  default = "Europe"
  validation {
    condition     = can(regex("^(?:India|Singapore|Europe|US)$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain."
  }
}
variable "primary_google_workspace_admin_email_address" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9.!#$%&'*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)$", var.primary_google_workspace_admin_email_address))
    error_message = "Invalid email address."
  }
}
variable "coralogix_private_key" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}$", var.coralogix_private_key))
    error_message = "The PrivateKey should be valid UUID string."
  }
}
variable "coralogix_application_name" {
  type = string
}
variable "coralogix_subsystem_name" {
  type = string
}
variable "coralogix_company_id" {
  type = string
  validation {
    condition     = can(regex("^\\d{5,7}$", var.coralogix_company_id))
    error_message = "Invalid company ID."
  }
}

resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}
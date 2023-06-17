// GCP
variable "gcp_machine_type" {
  type    = string
  default = "e2-highcpu-2"
}
variable "gcp_boot_disk_type" {
  type    = string
  default = "pd-balanced"
  validation {
    condition     = can(regex("^(pd-balanced|pd-standard|pd-ssd|pd-extreme)$", var.gcp_boot_disk_type))
    error_message = "Invalid dick type."
  }
}
variable "gcp_project_subnetwork_vpc" {
  type        = string
  description = "The sub network to provision the instance in"
}
variable "gcp_zone" {
  type        = string
  description = "GCP Zone"
}
variable "gcp_project_id" {
  type        = string
  description = "GCP project name"
}
variable "gcp_block_project_ssh_keys" {
  type    = bool
  default = false
}
variable "gcp_instance_enable_vtpm" {
  type = bool
}
variable "gcp_instance_enable_secure_boot" {
  type = bool
}
variable "gcp_instance_enable_integrity_monitoring" {
  type = bool
}
variable "gcp_instance_kms_key_self_link" {
  type = string
}

// Google Workspace
variable "google_workspace_primary_admin_email_address" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9.!#$%&'*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)$", var.google_workspace_primary_admin_email_address))
    error_message = "Invalid email address."
  }
}

// Coralogix
variable "coralogix_applicationName" {
  type        = string
  description = "Application name for Coralogix account (no spaces)"
}
variable "coralogix_domain" {
  type    = string
  default = "Europe"
  validation {
    condition     = can(regex("^(?:India|Singapore|Europe|US|Europe2)$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain."
  }
}
variable "coralogix_private_key" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}$", var.coralogix_private_key))
    error_message = "The PrivateKey should be valid UUID string."
  }
}
// GCP
variable "gcp_machine_type" {
  type    = string
  description = "The machine type for the audit collector"
  default = "e2-highcpu-2"
}
variable "gcp_boot_disk_type" {
  type    = string
  description = "Disk type for the audit collector"
  default = "pd-balanced"
  validation {
    condition     = can(regex("^(pd-balanced|pd-standard|pd-ssd|pd-extreme)$", var.gcp_boot_disk_type))
    error_message = "Invalid dick type."
  }
}
variable "gcp_project_subnetwork_vpc" {
  type        = string
  description = "The sub network to provision the audit collector"
}
variable "gcp_zone" {
  type        = string
  description = "GCP Zone"
}
variable "gcp_project_id" {
  type        = string
  description = "GCP project ID"
}
variable "gcp_block_project_ssh_keys" {
  type    = bool
  description = "Whether to allow project level SSH keys to access the instance"
  default = false
}
variable "gcp_instance_enable_vtpm" {
  type = bool
  description = "Enable or disable the Virtual Trusted Platform Module"
  default = false
}
variable "gcp_instance_enable_secure_boot" {
  type = bool
  description = "Enable or disable instance secure boot"
  default = false
}
variable "gcp_instance_enable_integrity_monitoring" {
  type = bool
  description = "Enable or disable integrity monitoring"
  default = false
}
variable "gcp_instance_kms_key_self_link" {
  type = string
  description = "Enable or disable KMS key for self link"
  default = ""
}

// Google Workspace
variable "google_workspace_primary_admin_email_address" {
  type = string
  description = "The Primary admin (only) of the Google Workspace domain"
  validation {
    condition     = can(regex("^[a-zA-Z0-9.!#$%&'*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)$", var.google_workspace_primary_admin_email_address))
    error_message = "Invalid email address."
  }
}

// Coralogix
variable "coralogix_applicationName" {
  type        = string
  description = "Application name for Coralogix account (no spaces)"
  validation {
    condition = can(regex("^\\w{4,30}$", var.coralogix_applicationName))
    error_message = "Invalid Coralogix application name."
  }
}
variable "coralogix_domain" {
  type    = string
  default = "Europe"
  description = "Can be either 'India', 'Singapore', 'US', 'Europe' or 'Europe2'"
  validation {
    condition     = can(regex("^(?:India|Singapore|Europe|US|Europe2)$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain."
  }
}
variable "coralogix_private_key" {
  type = string
  description = "The 'Send Your Data' API key from the Coralogix account"
  sensitive = true
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}$", var.coralogix_private_key))
    error_message = "The PrivateKey should be valid UUID string."
  }
}
#--------------------------------
#         General GCP
#--------------------------------
variable "service_account" {
  type        = string
  description = "The service account with the CSPM permissions"
}
variable "project_name" {
  type        = string
  description = "GCP project name"
}
variable "zone" {
  type        = string
  description = "GCP Zone"
}
variable "credentials_file" {
  type        = string
  description = "The full path to the credentials JSON file"
}

#-------------------------------
#          Instance
#--------------------------------
variable "project_subnetwork_vpc" {
  type        = string
  description = "The sub network to provision the CSPM in"
}
variable "machine_type" {
  type    = string
  default = "e2-highcpu-2"
}
variable "boot_disk_type" {
  type    = string
  default = "pd-balanced"
  validation {
    condition     = can(regex("^(pd-balanced|pd-standard|pd-ssd|pd-extreme)$", var.boot_disk_type))
    error_message = "Invalid dick type"
  }
}

#---------------------------------
#        Coralogix
#---------------------------------
variable "GRPC_Endpoint" {
  type        = string
  default     = "Europe"
  description = "The address of the GRPC endpoint for the coralogix account"
  validation {
    condition     = can(regex("^(Europe|Europe2|India|Singapore|US)$", var.GRPC_Endpoint))
    error_message = "Invalid GRPC endpoint"
  }
}
variable "applicationName" {
  type        = string
  default     = "cspm"
  description = "Application name for Coralogix account (no spaces)"
}
variable "subsystemName" {
  type        = string
  default     = "cspm"
  description = "Subsystem name for Coralogix account (no spaces)"
}
variable "PrivateKey" {
  type        = string
  default     = ""
  description = "The API Key from the Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}", var.PrivateKey))
    error_message = "The PrivateKey should be valid UUID string"
  }
}
variable "alertAPIkey" {
  type        = string
  description = "The Alert API key from the Coralogix account"
  default     = ""
  sensitive   = true
}
variable "Company_ID" {
  type        = string
  description = "The Coralogix team company ID"
  validation {
    condition     = can(regex("^\\d{5,10}", var.Company_ID))
    error_message = "Invalid Company ID"
  }
}
variable "grpc-endpoints-map" {
  type    = map(string)
  default = {
    Europe    = "ng-api-grpc.coralogix.com"
    Europe2   = "ng-api-grpc.eu2.coralogix.com"
    India     = "ng-api-grpc.app.coralogix.in"
    Singapore = "ng-api-grpc.coralogixsg.com"
    US        = "ng-api-grpc.coralogix.us"
  }
}

#----------------------------------
#           CSPM
#----------------------------------
variable "CSPMVersion" {
  type        = string
  default     = "latest"
  description = "Versions can by checked at: https://hub.docker.com/r/coralogixrepo/snowbit-cspm/"
}
variable "TesterList" {
  type        = string
  default     = ""
  description = "Services for next scan"
}
variable "RegionList" {
  type    = string
  default = ""
}
variable "cronjob" {
  type    = string
  default = "0 0 * * *"
  validation {
    condition     = can(regex("^((\\d|\\*)\\s){4}(\\d|\\*)$", var.cronjob))
    error_message = "Invalid cronjob pattern"
  }
}

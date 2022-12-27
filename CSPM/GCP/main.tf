variable "applicationName" {}
variable "subsystemName" {}
variable "GRPC_Endpoint" {}
variable "PrivateKey" {}
variable "alertAPIkey" {}
variable "Company_ID" {}
variable "CSPMVersion" {}
variable "TesterList" {}
variable "RegionList" {}
variable "cronjob" {}
variable "project_subnetwork_vpc" {}
variable "machine_type" {}
variable "boot_disk_type" {}
variable "service_account" {}
variable "project_name" {}
variable "zone" {}
variable "credentials_file" {}

module "CSPM" {
  source = "github.com/coralogix/snowbit-modules//GCP"

  applicationName        = var.applicationName
  subsystemName          = var.subsystemName
  GRPC_Endpoint          = var.GRPC_Endpoint
  PrivateKey             = var.PrivateKey
  alertAPIkey            = var.alertAPIkey
  Company_ID             = var.Company_ID
  project_subnetwork_vpc = var.project_subnetwork_vpc
  service_account        = var.service_account
  project_name           = var.project_name
  zone                   = var.zone
  credentials_file       = var.credentials_file
#  CSPMVersion            = var.CSPMVersion
#  TesterList             = var.TesterList
#  RegionList             = var.RegionList
#  cronjob                = var.cronjob
#  machine_type           = var.machine_type
#  boot_disk_type         = var.boot_disk_type
}

output "applicationName" {
  value = var.applicationName
}
output "subsystemName" {
  value = var.subsystemName
}
output "GRPC_Endpoint" {
  value = var.GRPC_Endpoint
}
output "PrivateKey" {
  value = var.PrivateKey
}
output "alertAPIkey" {
  value = var.alertAPIkey
}
output "Company_ID" {
  value = var.Company_ID
}
output "project_subnetwork_vpc" {
  value = var.project_subnetwork_vpc
}
output "service_account" {
  value = var.service_account
}
output "project_name" {
  value = var.project_name
}
output "zone" {
  value = var.zone
}
output "credentials_file" {
  value = var.credentials_file
}
output "CSPMVersion" {
  value = var.CSPMVersion
}
output "TesterList" {
  value = var.TesterList
}
output "RegionList" {
  value = var.RegionList
}
output "cronjob" {
  value = var.cronjob
}
output "machine_type" {
  value = var.machine_type
}
output "boot_disk_type" {
  value = var.boot_disk_type
}

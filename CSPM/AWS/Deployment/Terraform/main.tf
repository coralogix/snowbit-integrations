variable "Subnet_ID" {}
variable "PrivateKey" {}
variable "GRPC_Endpoint" {}
variable "SSHKeyName" {}
variable "Company_ID" {}
variable "security_group_id" {}
variable "alertAPIkey" {}
variable "ebs_encryption" {}
variable "public_instance" {}
variable "SSHIpAddress" {}
variable "applicationName" {}
variable "subsystemName" {}
variable "cronjob" {}
variable "additional_tags" {}
variable "instanceType" {}
variable "DiskType" {}
variable "TesterList" {}
variable "RegionList" {}
variable "multiAccountsARN" {}
variable "CSPMVersion" {}

module "CSPM" {
  source = "s3::https://snowbit-shared-resources.s3.eu-west-1.amazonaws.com/CSPM/Terraform/Deployment"

  PrivateKey    = var.PrivateKey
  Subnet_ID     = var.Subnet_ID
  GRPC_Endpoint = var.GRPC_Endpoint
  SSHKeyName    = var.SSHKeyName
  Company_ID    = var.Company_ID
  #  additional_tags         = var.additional_tags
  #  applicationName         = var.applicationName
  #  subsystemName           = var.subsystemName
  #  security_group_id       = var.security_group_id
  #  alertAPIkey             = var.alertAPIkey
  #  ebs_encryption          = var.ebs_encryption
  #  public_instance         = var.public_instance
  #  cronjob                 = var.cronjob
  #  instanceType            = var.instanceType
  #  SSHIpAddress            = var.SSHIpAddress
  #  CSPMVersion             = var.CSPMVersion
  #  DiskType                = var.DiskType
  #  TesterList              = var.TesterList
  #  RegionList              = var.RegionList
  #  multiAccountsARN        = var.multiAccountsARN
}

output "Coralogix-Private-Key" {
  value     = var.PrivateKey
  sensitive = true
}
output "CoralogixCompany-ID" {
  value = var.Company_ID
}
output "Subnet-ID" {
  value = var.Subnet_ID
}
output "GRPC-Endpoint" {
  value = var.GRPC_Endpoint
}
output "SSH-Key-Name" {
  value = var.SSHKeyName
}
output "Security-Group-ID" {
  value = var.security_group_id
}
output "Alert-API-key" {
  value     = var.alertAPIkey
  sensitive = true
}
output "EBS-Encryption" {
  value = var.ebs_encryption
}
output "Public-Instance" {
  value = var.public_instance
}
output "Cronjob-Frequency" {
  value = var.cronjob
}
output "Instance-Type" {
  value = var.instanceType
}
output "SSH-IP-Ingress-Address" {
  value = var.SSHIpAddress
}
output "Application-Name" {
  value = var.applicationName
}
output "Subsystem-Name" {
  value = var.subsystemName
}
output "CSPM-Version" {
  value = var.CSPMVersion
}
output "Disk-Type" {
  value = var.DiskType
}
output "Tester-List" {
  value = var.TesterList
}
output "Region-List" {
  value = var.RegionList
}
output "Role-ARN-of-Additional-Account" {
  value = var.multiAccountsARN
}
output "Additional-Tags" {
  value = var.additional_tags
}
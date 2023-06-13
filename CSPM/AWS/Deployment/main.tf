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
variable "additional_tags" {}
variable "instanceType" {}
variable "DiskType" {}
variable "TesterList" {}
variable "RegionList" {}
variable "multiAccountsARNs" {}

module "CSPM" {
  source = "github.com/coralogix/snowbit-modules//CSPM/AWS"

  PrivateKey        = var.PrivateKey
  Subnet_ID         = var.Subnet_ID
  GRPC_Endpoint     = var.GRPC_Endpoint
  SSHKeyName        = var.SSHKeyName
  Company_ID        = var.Company_ID
  instanceType      = var.instanceType
  SSHIpAddress      = var.SSHIpAddress
  DiskType          = var.DiskType
  alertAPIkey       = var.alertAPIkey
  additional_tags   = var.additional_tags
  applicationName   = var.applicationName
  subsystemName     = var.subsystemName
  security_group_id = var.security_group_id
  ebs_encryption    = var.ebs_encryption
  public_instance   = var.public_instance
  TesterList        = var.TesterList
  RegionList        = var.RegionList
  multiAccountsARNs = var.multiAccountsARNs
}

output "CSPM" {
  value = module.CSPM.CSPM
}
output "AWS" {
  value = module.CSPM.AWS
}
output "Coralogix" {
  value = module.CSPM.Coralogix
}
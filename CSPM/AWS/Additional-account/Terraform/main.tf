variable "master-account-id" {}
variable "additional_tags" {}
module "adding-account-CSPM" {
  source = "s3::https://snowbit-shared-resources.s3.eu-west-1.amazonaws.com/CSPM/Terraform/Adding-additional-account-to-Deployment"

  master-account-id = var.master-account-id
  #additional_tags = {}
}
output "Master-Account-ID" {
  value = var.master-account-id
}
output "Additional-Tags" {
  value = var.additional_tags
}
variable "coralogix_private_key" {}
variable "coralogix_domain" {}
variable "coralogix_company_id" {}
variable "aws_subnet_id" {}
variable "aws_ssh_key_name" {}
variable "aws_additional_tags" {}

module "Coralogix_Integrations" {
  source = "./modules"

  // General information
  coralogix_private_key = var.coralogix_private_key
  coralogix_domain      = var.coralogix_domain
  coralogix_company_id  = var.coralogix_company_id
  aws_subnet_id         = var.aws_subnet_id
  aws_ssh_key_name      = var.aws_ssh_key_name
  aws_additional_tags   = var.aws_additional_tags

  // Okta
  okta_integration_required = false
  okta_application_name     = var.okta_application_name
  okta_subsystem_name       = var.okta_subsystem_name
  okta_api_key              = var.okta_api_key
  okta_domain               = var.okta_domain

  // Google Workspace
  google_workspace_integration_required           = false
  google_workspace_application_name               = var.google_workspace_application_name
  google_workspace_subsystem_name                 = var.google_workspace_subsystem_name
  google_workspace_primary_admin_email_address    = var.google_workspace_primary_admin_email_address
  google_workspace_existing_project_id            = var.google_workspace_existing_project_id
  google_workspace_service_account_display_name   = var.google_workspace_service_account_display_name
  # when creating a new project for the integrations using this terraform module
  google_workspace_new_project_name               = var.google_workspace_new_project_name
  google_workspace_new_project_organization_id    = var.google_workspace_new_project_organization
  google_workspace_new_project_billing_account_id = var.google_workspace_new_project_billing_account

  // JumpCloud
  jumpcloud_integration_required = false
  jumpcloud_application_name     = var.jumpcloud_application_name
  jumpcloud_subsystem_name       = var.jumpcloud_subsystem_name
  jumpcloud_api_key              = var.jumpcloud_api_key

  //CrowdStrike
  crowdstrike_integration_required = false
  crowdstrike_application_name     = var.crowdstrike_application_name
  crowdstrike_subsystem_name       = var.crowdstrike_subsystem_name
  crowdstrike_client_id            = var.crowdstrike_client_id
  crowdstrike_client_secret        = var.crowdstrike_client_secret
  crowdstrike_api_url              = var.crowdstrike_api_url
}

variable "okta_application_name" {}
variable "okta_subsystem_name" {}
variable "okta_api_key" {}
variable "okta_domain" {}
variable "crowdstrike_application_name" {}
variable "crowdstrike_subsystem_name" {}
variable "crowdstrike_client_id" {}
variable "crowdstrike_client_secret" {}
variable "crowdstrike_api_url" {}
variable "google_workspace_application_name" {}
variable "google_workspace_subsystem_name" {}
variable "google_workspace_primary_admin_email_address" {}
variable "google_workspace_existing_project_id" {}
variable "google_workspace_service_account_display_name" {}
variable "google_workspace_new_project_name" {}
variable "google_workspace_new_project_organization" {}
variable "google_workspace_new_project_billing_account" {}
variable "jumpcloud_application_name" {}
variable "jumpcloud_subsystem_name" {}
variable "jumpcloud_api_key" {}

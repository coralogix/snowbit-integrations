# General - Mandatory
coralogix_private_key                        = ""
coralogix_application_name                   = ""
coralogix_subsystem_name                     = ""
coralogix_company_id                         = ""
coralogix_domain                             = ""      # Europe, India, Singapore or US
instance_cloud_provider                      = ""      # 'AWS' or 'GCP'
primary_google_workspace_admin_email_address = ""      # in the Google Workspace console under 'Account > Account Settings'

# GCP - Mandatory
existing_project_id          = ""                      # Optional when filling new project information below
service_account_display_name = ""
# GCP - Optional - If a new project is required
new_project_name             = ""
new_project_organization     = ""                      # When creating a new project
new_project_billing_account  = ""                      # When creating a new project
# When using instance in GCP
machine_type                 = ""                      # Defaults to 'e2-highcpu-2'
boot_disk_type               = ""                      # Defaults to 'pd-balanced'

# When using instance in AWS - Optional
ssh_key               = ""
subnet_id             = ""
public_instance       = true
ec2_volume_encryption = true
SSHIpAddress          = ""
security_group_id     = ""
additional_tags       = {
  #  Example_Key = "Example Value"
}

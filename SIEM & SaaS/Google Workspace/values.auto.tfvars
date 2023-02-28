# Coralogix
coralogix_private_key      = ""
coralogix_application_name = ""
coralogix_subsystem_name   = ""
coralogix_company_id       = ""
coralogix_domain           = ""                   # Europe, India, Singapore or US

# Google Workspace
primary_google_workspace_admin_email_address = "" # in the Google Workspace console under 'Account > Account Settings'

# GCP
existing_project_id          = ""                 # Optional when filling new project information below
service_account_id           = ""
service_account_display_name = ""
# If a new project is required                    # Optional
new_project_name             = ""                 # Optional
new_project_organization     = ""                 # Optional
new_project_billing_account  = ""                 # Optional

# AWS
ssh_key               = ""
subnet_id             = ""
public_instance       = true
ec2_volume_encryption = true
SSHIpAddress          = ""
security_group_id     = ""
additional_tags       = {
  #  Example_Key = "Example Value"
}

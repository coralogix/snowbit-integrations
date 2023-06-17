coralogix_applicationName                    = ""
coralogix_domain                             = "" # Can be
coralogix_private_key                        = ""
gcp_project_subnetwork_vpc                   = "" # The subnet inside a VPC
gcp_zone                                     = ""
gcp_project_id                               = ""
google_workspace_primary_admin_email_address = "" # The full primary admin email address for the domain

# Instance Security
gcp_block_project_ssh_keys  = false
enable_vtpm                 = false
enable_secure_boot          = false
enable_integrity_monitoring = false
kms_key_self_link           = "" # Optionall
coralogix_applicationName                    = "test"
coralogix_domain                             = "India" # Can be either 'India', 'Singapore', 'US', 'Europe' or 'Europe2'
coralogix_private_key                        = "a33bfdcc-3e23-462b-8b6c-f331fc1156e2"
gcp_project_subnetwork_vpc                   = "nir-subnet-1" # The subnet inside a VPC
gcp_zone                                     = "us-central1-a"
gcp_project_id                               = "nir-limor"
google_workspace_primary_admin_email_address = "admin@cparanoid.com" # The full primary admin email address for the domain

# Instance Security
gcp_block_project_ssh_keys  = false
gcp_instance_enable_vtpm                 = false
gcp_instance_enable_secure_boot          = false
gcp_instance_enable_integrity_monitoring = false
gcp_instance_kms_key_self_link           = "" # Optionall
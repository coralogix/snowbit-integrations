coralogix_private_key      = ""
coralogix_application_name = ""
coralogix_subsystem_name   = ""
coralogix_company_id       = ""
coralogix_domain           = ""     # 'Europe', 'India', 'Singapore' or 'US'
instanceType               = ""     # Defaults to 't3a.small'
SSHKeyName                 = ""     # To access the EC2 instance - optional
public_instance            = true
Subnet_ID                  = ""     # For the EC2 instance
security_group_id          = ""     # Optional
SSHIpAddress               = ""     # Optional
additional_tags            = {      # Optional
  # example_key = "example value"
}

okta_api_key = ""
okta_domain  = ""
client_id                  = "client id test"
client_secret              = "client secret test"
api_url                    = "api.eu2.crowdstrike.com"        # api.crowdstrike.com
coralogix_private_key      = ""
coralogix_application_name = "cs-test"
coralogix_subsystem_name   = "cs-test"
coralogix_domain           = "Europe"     # 'Europe', 'Europe2', 'India', 'Singapore' or 'US'
instanceType               = ""     # Defaults to 't3a.small'
SSHKeyName                 = "ireland"     # To access the EC2 instance - optional
public_instance            = true
Subnet_ID                  = ""     # For the EC2 instance
security_group_id          = ""     # Optional
SSHIpAddress               = ""     # Optional
additional_tags            = {      # Optional
  # example_key = "example value"
}
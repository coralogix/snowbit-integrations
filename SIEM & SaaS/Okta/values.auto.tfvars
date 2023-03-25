coralogix_private_key      = "39736fd1-22e2-bb84-ed21-c3a59785e097"
coralogix_application_name = "okta-test"
coralogix_subsystem_name   = "okta-test"
coralogix_company_id       = "26124"
coralogix_domain           = "US"     # 'Europe', 'India', 'Singapore' or 'US'
instanceType               = ""     # Defaults to 't3a.small'
SSHKeyName                 = "ireland"     # To access the EC2 instance - optional
public_instance            = true
Subnet_ID                  = "subnet-04bb5267196323c98"     # For the EC2 instance
security_group_id          = ""     # Optional
SSHIpAddress               = ""     # Optional
additional_tags            = {      # Optional
  # example_key = "example value"
}
okta_api_key = "00SFiG2gzWhzq1x_SvjDfthjoK3wIceQrxGS8PV1co"
okta_domain  = "trial-8018743.okta.com"

# 39736fd122e2bb84ed21c3a59785e097
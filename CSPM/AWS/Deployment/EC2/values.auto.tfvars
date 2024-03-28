# ------- Coralogix ------- #
Coralogix-PrivateKey      = ""
Coralogix-Company_ID      = ""
Coralogix-applicationName = ""  # (Optional) Defaults to 'CSPM'
Coralogix-subsystemName   = ""  # (Optional) Defaults to 'CSPM'
Coralogix-alertAPIkey     = ""  # (Optional)
Coralogix-GRPC_Endpoint   = ""  # Can be either 'Europe','Europe2','India','Singapore' or 'US'

# ------- CSPM ------- #
CSPM-multiAccountsARNs = []     # (Optional) - To scan multiple accounts
CSPM-TesterList        = ""
CSPM-RegionList        = ""

# ------- AWS ------- #
AWS-instanceType      = "t3a.medium"
AWS-Subnet_ID         = ""
AWS-security_group_id = ""
AWS-SSHKeyName        = ""
AWS-SSHIpAddress      = ""
AWS-ebs_encryption    = true
AWS-public_instance   = true
AWS-additional_tags   = {} ## Optional

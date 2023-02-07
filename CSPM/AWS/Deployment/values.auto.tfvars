#=======================================================================================================
#                                   Mandatory Variables:
#=======================================================================================================
PrivateKey              = ""            # From Coralogix account
Company_ID              = ""            # From Coralogix account
Subnet_ID               = ""
GRPC_Endpoint           = ""            # Can be either - Europe, Europe2, India, Singapore or US
SSHKeyName              = ""            # Without the '.pem'

# ======================================================================================================
#             Optional Variables - When adding variables, remove comment in the module
# ======================================================================================================

# --- CSPM Instance & AWS Account
security_group_id       = ""
ebs_encryption          = false         # Boolean
public_instance         = true          # Boolean
SSHIpAddress            = ""            # The public IP address for SSH access to the EC2 instance
instanceType            = ""            # https://aws.amazon.com/ec2/instance-types/
DiskType                = ""            # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html
additional_tags         = {
  example-key = "example-value"
}

# --- CSPM Configurations
cronjob                 = ""            # correct format - # # # # # - for help https://crontab.guru/
CSPMVersion             = ""            # Default is 'latest' - for additional information refer to https://hub.docker.com/r/coralogixrepo/snowbit-cspm/tags
TesterList              = ""
RegionList              = ""
multiAccountsARNs       = ""           # ARN(s) for one more account to scan - for additional information refer to https://coralogix.com/docs/cloud-security-posture-cspm/

# --- Coralogix Account
alertAPIkey             = ""
applicationName         = ""            # For the Coralogix account
subsystemName           = ""            # For the Coralogix account




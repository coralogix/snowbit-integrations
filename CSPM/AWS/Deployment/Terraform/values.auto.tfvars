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
security_group_id       = ""
alertAPIkey             = ""
ebs_encryption          = ""            # Boolean
public_instance         = ""            # Boolean
cronjob                 = ""            # correct format - # # # # # - for help https://crontab.guru/
instanceType            = ""            # https://aws.amazon.com/ec2/instance-types/
SSHIpAddress            = ""            # The public IP address for SSH access to the EC2 instance
applicationName         = ""            # For the Coralogix account
subsystemName           = ""            # For the Coralogix account
CSPMVersion             = ""            # Default is 'latest' - for additional information refer to https://hub.docker.com/r/coralogixrepo/snowbit-cspm/tags
DiskType                = ""            # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html
TesterList              = ""
RegionList              = ""
multiAccountsARN        = ""            # ARN for one more account to scan - for additional information refer to https://coralogix.com/docs/cloud-security-posture-cspm/
additional_tags         = {
  # example-key = "example-value"
}


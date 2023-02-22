#
#   $$$$$$\                                    $$\       $$\   $$\           $$$$$$\   $$$$$$\  $$$$$$$\  $$\      $$\
#  $$  __$$\                                   $$ |      \__|  $$ |         $$  __$$\ $$  __$$\ $$  __$$\ $$$\    $$$ |
#  $$ /  \__|$$$$$$$\   $$$$$$\  $$\  $$\  $$\ $$$$$$$\  $$\ $$$$$$\        $$ /  \__|$$ /  \__|$$ |  $$ |$$$$\  $$$$ |
#  \$$$$$$\  $$  __$$\ $$  __$$\ $$ | $$ | $$ |$$  __$$\ $$ |\_$$  _|       $$ |      \$$$$$$\  $$$$$$$  |$$\$$\$$ $$ |
#   \____$$\ $$ |  $$ |$$ /  $$ |$$ | $$ | $$ |$$ |  $$ |$$ |  $$ |         $$ |       \____$$\ $$  ____/ $$ \$$$  $$ |
#  $$\   $$ |$$ |  $$ |$$ |  $$ |$$ | $$ | $$ |$$ |  $$ |$$ |  $$ |$$\      $$ |  $$\ $$\   $$ |$$ |      $$ |\$  /$$ |
#  \$$$$$$  |$$ |  $$ |\$$$$$$  |\$$$$$\$$$$  |$$$$$$$  |$$ |  \$$$$  |     \$$$$$$  |\$$$$$$  |$$ |      $$ | \_/ $$ |
#   \______/ \__|  \__| \______/  \_____\____/ \_______/ \__|   \____/       \______/  \______/ \__|      \__|     \__|
#
# ======================================================================================================================
#                                           Mandatory Variables
# ======================================================================================================================
PrivateKey              = ""            # From Coralogix account
Company_ID              = ""            # From Coralogix account
Subnet_ID               = ""
GRPC_Endpoint           = ""            # Can be either - Europe, Europe2, India, Singapore or US
SSHKeyName              = ""            # Without the '.pem'
ebs_encryption          = false         # Boolean
public_instance         = true          # Boolean

# ======================================================================================================================
#                                           Optional Variables
# ======================================================================================================================

# --- CSPM Instance & AWS Account
security_group_id       = ""            # Optional - if not provided, a new security group will be created
SSHIpAddress            = ""            # When not using 'security_group_id', choose the public IP address for SSH access to the EC2 instance used in the new security group
instanceType            = ""            # defaults to 't3.small' - for additional information: https://aws.amazon.com/ec2/instance-types/
DiskType                = ""            # defaults to 'gp3' - available values are 'gp2' and 'gp3' for additional information: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html
additional_tags         = {
#  example-key = "example-value"
}

# --- CSPM Configurations
TesterList              = ""
RegionList              = ""
multiAccountsARNs       = ""           # ARN(s) for one more account to scan - for additional information refer to https://coralogix.com/docs/cloud-security-posture-cspm/

# --- Coralogix Account
alertAPIkey             = ""            # From Coralogix account. used for the CSPM custom enrichment
applicationName         = ""            # For the Coralogix account. defaults to 'CSPM'
subsystemName           = ""            # For the Coralogix account. defaults to 'CSPM'




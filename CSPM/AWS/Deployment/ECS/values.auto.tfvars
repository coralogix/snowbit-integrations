Cluster_Name                            = ""
GRPC_Endpoint_Location                  = ""  # Can be either 'Europe','Europe2','India','Singapore' or 'US'
PrivateKey                              = ""
Company_ID                              = ""
#applicationName                 = ""  # (Optional) Defaults to 'CSPM'
#subsystemName                   = ""  # (Optional) Defaults to 'CSPM'
event_target_subnets                    = ["subnet-123", "subnet-456"] # Array
event_target_ecs_target_security_groups = ["sg-123", "sg-456"] # Array
alertAPIkey                             = "" # (Optional)
Role_ARN_List                           = "" # (Optional) - To scan multiple accounts

additional_tags = {} ## Optional
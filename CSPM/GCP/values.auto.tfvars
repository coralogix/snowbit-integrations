#--------------------------------------------
#               General GCP
#--------------------------------------------
service_account  = ""
project_name     = ""
zone             = ""
credentials_file = ""             # The full path to the credentials JSON file

#--------------------------------------------
#                 Instance
#--------------------------------------------
project_subnetwork_vpc = ""
#machine_type           = ""
#boot_disk_type         = ""

#--------------------------------------------
#                  Coralogix
#--------------------------------------------
GRPC_Endpoint   = ""               # Can be either - Europe, Europe2, India, Singapore or US
applicationName = ""               # For the Coralogix account
subsystemName   = ""               # For the Coralogix account
PrivateKey      = ""
alertAPIkey     = ""
Company_ID      = ""               # Number

#--------------------------------------------
#                    CSPM
#--------------------------------------------
#CSPMVersion = ""
#TesterList  = ""
#RegionList  = ""
#cronjob     = ""
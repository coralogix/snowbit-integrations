# ----------------------------------------------------------
#                       AWS
# ----------------------------------------------------------
lambda_application_name   = ""               # Defaults to 'CloudWatch-to-Coralogix'
log_group_name            = ""
kms_key_arn               = ""               # Optional
additional_tags           = {
#  test = "value"
}

# ----------------------------------------------------------
#                       Coralogix
# ----------------------------------------------------------
private_key               = ""
application_name          = ""
subsystem_name            = ""

# ----------------------------------------------------------
#                       AWS
# ----------------------------------------------------------
function_name         = ""               # Defaults to 'CloudWatch-to-Coralogix'
log_group_name                  = ""
kms_key_id_for_lambda_log_group = ""
additional_tags                 = {
  #  test = "value"
}

# ----------------------------------------------------------
#                       Coralogix
# ----------------------------------------------------------
private_key      = ""
application_name = ""
subsystem_name   = ""

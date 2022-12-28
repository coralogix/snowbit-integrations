# ----------------------------------------------------------
#                       AWS
# ----------------------------------------------------------
lambda_application_name         = "guradduty-lambda"               # Defaults to 'CloudWatch-to-Coralogix'
log_group_name                  = "/aws/cloudtrail/audit-trail"
kms_key_id_for_lambda_log_group = ""
additional_tags                 = {
  #  test = "value"
}

# ----------------------------------------------------------
#                       Coralogix
# ----------------------------------------------------------
private_key      = "39736fd1-22e2-bb84-ed21-c3a59785e097"
application_name = "test-gd-1"
subsystem_name   = "test-gd-1"

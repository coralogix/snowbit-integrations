# ----------------------------------------------------------
#                       AWS
# ----------------------------------------------------------
lambda_application_name = ""               # Defaults to 'CloudWatch-to-Coralogix'
log_group_name          = "/aws/cloudtrail/audit-trail"
kms_key_arn             = ""               # Optional
additional_tags         = {
  test = "value"
}

# ----------------------------------------------------------
#                       Coralogix
# ----------------------------------------------------------
private_key      = "39736fd1-22e2-bb84-ed21-c3a59785e097"
application_name = "cloudwatch-integrations-test-2"
subsystem_name   = "cloudwatch-integrations-test"

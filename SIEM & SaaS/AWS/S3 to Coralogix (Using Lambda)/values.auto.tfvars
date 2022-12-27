application_name            = ""
subsystem_name              = ""
private_key                 = ""
coralogix_region            = ""                  # Can be either Europe, Europe2, India, Singapore or US
kms_id_for_s3               = ""                  # The KMS key that the Lambda would use to decrypt the logs
kms_id_for_lambda_log_group = ""
s3-bucket                   = ""
function_name               = ""
additional_tags             = {
  #  Example_key = "example value"
}
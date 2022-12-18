application_name            = ""
subsystem_name              = ""
private_key                 = ""
coralogix_region            = ""                  # Can be either Europe, Europe2, India, Singapore or US
kms_id_for_s3               = ""                  # When the logs are encrypted, provide the KMS key that the Lambda would use for decryption
kms_id_for_lambda_log_group = ""                  # optional - require manual setup before the deployment
s3-bucket                   = ""
function_name               = ""
integration_type            = ""                  # Can be 's3' or 'cloudtrail'
additional_tags             = {
  #  Example_key = "example value"
}
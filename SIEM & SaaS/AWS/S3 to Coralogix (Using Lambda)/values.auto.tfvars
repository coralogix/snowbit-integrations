application_name      = "gd-test"
subsystem_name        = "gd-test"
private_key           = "d06e0c3b-14fc-3243-39f2-5f7f77616892"
coralogix_region      = "Europe"                  # Can be either Europe, Europe2, India, Singapore or US
kms_id_for_s3         = "3bfe11ee-277f-46a7-9d1b-9f6da6de6b90"                  # The KMS key that the Lambda would use to decrypt the logs
s3-bucket             = "guardduty-snowbit-testing"
function_name         = "guardduty-to-coralogix"
additional_tags       = {
  Owner = "Nir Limor"
}
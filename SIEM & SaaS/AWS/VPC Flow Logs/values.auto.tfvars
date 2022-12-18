s3_bucket_versioning             = ""         # Optional - Can be 'Disabled' or 'Enabled'
s3_bucket_acl                    = ""         # Can either be 'private', 'public-read', 'public-read-write', 'authenticated-read', 'aws-exec-read' or 'log-delivery-write'
s3_bucket_encryption             = false
log_format                       = ""         # Optional
kms_master_key_id_for_s3         = ""         # Optional
kms_master_key_id_for_cloudwatch = ""         # Optional
additional_tags                  = {
#  example_key = "example value"
}
vpc_flow_log_additional_values = {
  key1 = {
    vpc_id               = "vpc-1234567"
    traffic_type         = "ALL"
    log_destination_type = "s3"
  }
  key2 = {
    vpc_id               = "vpc-1234567"
    log_destination_type = "s3"
  }
  key3 = {
    vpc_id               = "vpc-5678901"
    log_destination_type = "cloud-watch-logs"
  }
}

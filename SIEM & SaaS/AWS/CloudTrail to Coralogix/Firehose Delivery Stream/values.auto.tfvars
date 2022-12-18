privateKey           = ""
coralogix_region     = ""                       # Can be either Europe, Europe2, India, Singapore or US
application_name     = ""
subsystemName        = ""
firehose_stream      = ""                       # Logical name for the stream
log_group_name       = ""                       # CloudWatch log group name to track
s3_bucket_versioning = "Disabled"               # Versioning can either be 'Enabled', 'Disabled' or 'Suspended'
s3_bucket_acl        = "private"                # Can either be 'private', 'public-read', 'public-read-write', 'authenticated-read', 'aws-exec-read' or 'log-delivery-write'
s3_bucket_encryption = true                     # Boolean
log_group_kms_key_id = ""
additional_tags      = {
#  example_key = "example value"
}
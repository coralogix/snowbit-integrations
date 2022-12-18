privateKey           = ""
application_name     = ""
subsystemName        = ""
coralogix_region     = ""   # Can be 'US', 'Singapore', 'Europe', 'Europe2' or 'India'
function_name        = ""   # Optional - the default is 'SQS_to_Coralogix'
sqs_queue_name       = ""   # Existing SQS that is configured on the S3 bucket
s3_bucket_to_monitor = ""   # The S3 bucket with CloudTrail logs to track
additional_tags      = {
#  example_key = "example value"
}
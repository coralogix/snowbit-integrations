privetKey        = "39736fd1-22e2-bb84-ed21-c3a59785e097"
coralogix_region = "Europe"                       # Can be either Europe, Europe2, India, Singapore or US
application_name = "cloudtrail-test"
subsystemName    = "cloudtrail-test"
firehose_stream  = "test-stream"                       # Logical name for the stream
log_group_name   = "aws-cloudtrail-logs-780995948479-521638b4"                     # CloudWatch log group name to track
log_group        = "execution-logs-test-group"                      # CloudWatch log group's logical name to save the execution logs of the stream
additional_tags = {
  example_key = "example value"
}
output "Coralogix-data" {
  value = {
    Application-Name = var.application_name
    Subsystem-Name   = var.subsystemName
    API-Key          = "Valid"
    Endpoint         = "${var.coralogix_region} - ${lookup(var.cx_region_map, var.coralogix_region)}"
  }
}
output "AWS-data" {
  value = {
    SQS-Queue                         = var.sqs_queue_name
    S3-used-for-logging               = var.s3_bucket_to_monitor
    Additional_tags_for_all_resources = var.additional_tags
  }
}
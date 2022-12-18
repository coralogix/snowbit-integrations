terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17.1"
    }
  }
}

locals {
    endpoint_url = {
      "us" = {
        url = "https://firehose-ingress.coralogix.us/firehose"
      }
      "singapore" = {
        url = "https://firehose-ingress.coralogixsg.com/firehose"
      }
      "ireland" = {
        url = "https://firehose-ingress.coralogix.com/firehose"
      }
      "india" = {
        url = "https://firehose-ingress.coralogix.in/firehose"
      }
      "stockholm" = {
        url = "https://firehose-ingress.eu2.coralogix.com/firehose"
      }
    }
  tags = {
    terraform-module         = "kinesis-firehose-to-coralogix"
    terraform-module-version = "v0.0.1"
    managed-by               = "coralogix-terraform"
  }
  application_name = var.application_name == "" ? "snowbit-cloudtrail" : var.application_name
  subsystem_name   = var.subsystemName == "" ? "snowbit-cloudtrail" : var.subsystemName
}

data "aws_caller_identity" "current_identity" {}
data "aws_region" "current_region" {}
# ====================================================================================================
#                                       variables
# ====================================================================================================

variable "privatekey" {
  description = "The 'send your data' API key from Coralogix account"
  sensitive   = true
}
variable "coralogix_region" {
  description = "Enter the Coralogix account region [in lower-case letters]: \n- us\n- singapore\n- ireland\n- india\n- stockholm"
}
variable "output_format" {
  description = "The output format of the cloudwatch metric stream: 'json' or 'opentelemetry0.7'"
  type        = string
  default     = "json"
}
variable "integration_type" {
  description = "The integration type of the firehose delivery stream: 'CloudWatch_Metrics_JSON', 'CloudWatch_Metrics_OpenTelemetry070' or 'CloudWatch_CloudTrail'"
  type        = string
  default     = "CloudWatch_CloudTrail"
}
variable "application_name" {
  description = "The application name for the log group in Coralogix"
  type        = string
}
variable "subsystemName" {
  description = "The sub-system name for the log group in Coralogix"
  type        = string
}
variable "log_group" {
  type        = string
  description = "The log group to to be created that will save the firehose execution logs"
}
variable "log_group_name" {
  type        = string
  description = "The existing log group that saves the CloudTrail logs in CloudWatch"
}
variable "firehose_stream" {
  description = "The AWS Kinesis firehose delivery stream name that will be created"
  type        = string
  default     = "firehose-stream"
}

# ====================================================================================================
#                                       Resources
# ====================================================================================================

resource "aws_kinesis_firehose_delivery_stream" "coralogix_stream" {
  tags        = local.tags
  name        = "coralogix-firehose"
  destination = "http_endpoint"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_to_coralogix.arn
    bucket_arn         = aws_s3_bucket.firehose_bucket.arn
    buffer_size        = 5
    buffer_interval    = 300
    compression_format = "GZIP"
  }

  http_endpoint_configuration {
    url                = local.endpoint_url[var.coralogix_region].url
    name               = "Coralogix"
    access_key         = var.privatekey
    buffering_size     = 6
    buffering_interval = 60
    s3_backup_mode     = "FailedDataOnly"
    role_arn           = aws_iam_role.firehose_to_coralogix.arn
    retry_duration     = 30
    cloudwatch_logging_options {
      log_stream_name = aws_cloudwatch_log_stream.firehose_logstream_dest.name
      enabled        = "true"
      log_group_name = aws_cloudwatch_log_group.firehose_loggroup.name
    }

    request_configuration {
      content_encoding = "GZIP"

      common_attributes {
        name  = "integrationType"
        value = var.integration_type
      }

      common_attributes {
        name  = "applicationName"
        value = local.application_name
      }

      common_attributes {
        name  = "subsystemName"
        value = local.subsystem_name
      }
    }
  }
}
resource "aws_iam_role" "firehose_to_coralogix" {
  tags               = local.tags
  name               = "coralogix-firehose"
  assume_role_policy = jsonencode({
    "Version"   = "2012-10-17",
    "Statement" = [
      {
        "Action"    = "sts:AssumeRole",
        "Principal" = {
          "Service" = "firehose.amazonaws.com"
        },
        "Effect" = "Allow",
        "Sid"    = ""
      }
    ]
  })
  inline_policy {
    name   = "test"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Effect" = "Allow",
          "Action" = [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
          ],
          "Resource" = [
            aws_s3_bucket.firehose_bucket.arn,
            "${aws_s3_bucket.firehose_bucket.arn}/*"
          ]
        },
        {
          "Effect" = "Allow",
          "Action" = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ],
          "Resource" = [
            "arn:aws:kms:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_identity.account_id}:key/key-id"
          ],
          "Condition" = {
            "StringEquals" = {
              "kms:ViaService" = "s3.${data.aws_region.current_region.name}.amazonaws.com"
            },
            "StringLike" = {
              "kms:EncryptionContext:aws:s3:arn" = "${aws_s3_bucket.firehose_bucket.arn}/prefix*"
            }
          }
        },
        {
          "Effect" = "Allow",
          "Action" = [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
          ],
          "Resource" = "arn:aws:kinesis:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_identity.account_id}:stream/${var.firehose_stream}"
        },
        {
          "Effect" = "Allow",
          "Action" = [
            "logs:PutLogEvents"
          ],
          "Resource" = [
            aws_cloudwatch_log_group.firehose_loggroup.arn
          ]
        }
      ]
    })
  }
}
resource "aws_iam_role" "cloudwatch_access" {
  tags               = local.tags
  name               = "cloudwatch_access"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "logs.${data.aws_region.current_region.name}.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name   = "cloudwatch_access_policy"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Effect" = "Allow",
          "Action" = [
            "firehose:PutRecord",
            "firehose:PutRecordBatch"
          ],
          "Resource" = [
            aws_kinesis_firehose_delivery_stream.coralogix_stream.arn
          ]
        }
      ]
    })
  }
}
resource "aws_s3_bucket" "firehose_bucket" {
  tags   = local.tags
  bucket = "firehose-stream-backup-${random_id.id.hex}"
}
resource "random_id" "id" {
  byte_length = 12
}
resource "aws_cloudwatch_log_group" "firehose_loggroup" {
  tags              = local.tags
  name              = "/aws/kinesisfirehose/${var.firehose_stream}"
  retention_in_days = 1
}
resource "aws_cloudwatch_log_stream" "firehose_logstream_dest" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose_loggroup.name
}
resource "aws_cloudwatch_log_subscription_filter" "filter_to_firehose" {
  name            = "filter_to_firehose"
  role_arn        = aws_iam_role.cloudwatch_access.arn
  log_group_name  = var.log_group_name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.coralogix_stream.arn
  depends_on      = [aws_kinesis_firehose_delivery_stream.coralogix_stream]
}
resource "aws_kinesis_firehose_delivery_stream" "coralogix_stream" {
  name        = var.firehose_stream
  destination = "http_endpoint"
  s3_configuration {
    role_arn           = aws_iam_role.firehose_to_coralogix.arn
    bucket_arn         = aws_s3_bucket.firehose_bucket.arn
    buffer_size        = 5
    buffer_interval    = 300
    compression_format = "GZIP"
  }
  http_endpoint_configuration {
    url                = lookup(var.cx_region_map, var.coralogix_region)
    name               = "Coralogix"
    access_key         = var.privateKey
    buffering_size     = 6
    buffering_interval = 60
    s3_backup_mode     = "FailedDataOnly"
    role_arn           = aws_iam_role.firehose_to_coralogix.arn
    retry_duration     = 30
    cloudwatch_logging_options {
      log_stream_name = aws_cloudwatch_log_stream.firehose_logstream_dest.name
      enabled         = "true"
      log_group_name  = aws_cloudwatch_log_group.firehose_loggroup.name
    }
    request_configuration {
      content_encoding = "GZIP"
      common_attributes {
        name  = "integrationType"
        value = var.integration_type
      }
      common_attributes {
        name  = "applicationName"
        value = var.application_name == "" ? "snowbit-cloudtrail" : var.application_name
      }
      common_attributes {
        name  = "subsystemName"
        value = var.subsystemName == "" ? "snowbit-cloudtrail" : var.subsystemName
      }
    }
  }
  tags = var.additional_tags
}
resource "aws_iam_role" "firehose_to_coralogix" {
  name               = "coralogix-firehose-${random_string.id.id}"
  assume_role_policy = jsonencode({
    "Version"   = "2012-10-17",
    "Statement" = [
      {
        "Action"    = "sts:AssumeRole",
        "Principal" = {
          "Service" = "firehose.amazonaws.com"
        },
        "Effect" = "Allow"
      }
    ]
  })
  inline_policy {
    name   = "coralogix-firehose-execution"
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
            "*"
          ],
          "Resource" = [
            aws_cloudwatch_log_group.firehose_loggroup.arn
          ]
        }
      ]
    })
  }
  tags = var.additional_tags
}
resource "aws_iam_role" "cloudwatch_access" {
  name               = "cloudwatch_access-${random_string.id.id}"
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
  tags = var.additional_tags
}
resource "aws_s3_bucket" "firehose_bucket" {
  bucket = "firehose-stream-backup-${random_string.id.id}"
  tags   = var.additional_tags
  force_destroy = true
}
resource "aws_s3_bucket_versioning" "firehose_bucket_versioning" {
  bucket = aws_s3_bucket.firehose_bucket.id
  versioning_configuration {
    status = var.s3_bucket_versioning
  }
}
resource "aws_s3_bucket_acl" "firehose_bucket_acl" {
  bucket = aws_s3_bucket.firehose_bucket.id
  acl    = var.s3_bucket_acl
}
resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_bucket_encryption" {
  count  = var.s3_bucket_encryption == true ? 1 : 0
  bucket = aws_s3_bucket.firehose_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "firehose_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.firehose_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_cloudwatch_log_group" "firehose_loggroup" {
  name              = "/aws/kinesisfirehose/${var.firehose_stream}"
  retention_in_days = 1
  tags              = var.additional_tags
  kms_key_id        = var.log_group_kms_key_id
}
resource "aws_cloudwatch_log_stream" "firehose_logstream_dest" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose_loggroup.name
}
resource "aws_cloudwatch_log_subscription_filter" "filter_to_firehose" {
  name            = "filter_to_firehose"
  role_arn        = aws_iam_role.cloudwatch_access.arn
  log_group_name  = aws_cloudwatch_log_group.firehose_loggroup.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.coralogix_stream.arn
  depends_on      = [aws_kinesis_firehose_delivery_stream.coralogix_stream]
}
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}
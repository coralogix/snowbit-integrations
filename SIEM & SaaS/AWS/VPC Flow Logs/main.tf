terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4"
    }
  }
}

variable "s3_bucket_versioning" {
  type = string
  validation {
    condition     = can(regex("^(Disabled|Enabled|Suspended)$", var.s3_bucket_versioning))
    error_message = "Versioning can either be 'Enabled', 'Disabled' or 'Suspended'"
  }
}
variable "s3_bucket_acl" {
  type = string
  validation {
    condition     = var.s3_bucket_acl == "private" || var.s3_bucket_acl == "public-read" || var.s3_bucket_acl == "public-read-write" || var.s3_bucket_acl == "authenticated-read" || var.s3_bucket_acl == "aws-exec-read" || var.s3_bucket_acl == "log-delivery-write"
    error_message = "Can either be 'private', 'public-read', 'public-read-write', 'authenticated-read', 'aws-exec-read' or 'log-delivery-write'"
  }
}
variable "s3_bucket_encryption" {
  type    = bool
  default = true
}
variable "vpc_flow_log_additional_values" {
  type = map(object({
    vpc_id               = string
    traffic_type         = optional(string)
    log_destination_type = string
    log_destination      = optional(string)
    s3_bucket_encryption = optional(bool)
    s3_bucket_acl        = optional(string)
  }))
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "log_format" {
  type    = string
  default = ""
}
variable "kms_master_key_id_for_s3" {
  type = string
  default = ""
}
variable "kms_master_key_id_for_cloudwatch" {
  type = string
  default = ""
}

locals {
  s3 = {
    for k, v in var.vpc_flow_log_additional_values : k => v
    if v.log_destination_type == "s3"
  }
  s3-needed  = length(local.s3) > 0 ? true : false
  cloudwatch = {
    for k, v in var.vpc_flow_log_additional_values : k => v
    if v.log_destination_type == "cloud-watch-logs"
  }
  cloudwatch-needed = length(local.cloudwatch) > 0 ? true : false
}

# Flow Log creation
resource "aws_flow_log" "this" {
  for_each             = var.vpc_flow_log_additional_values
  vpc_id               = each.value.vpc_id
  log_destination_type = each.value.log_destination_type
  traffic_type         = each.value.traffic_type == null ? "ALL" : each.value.traffic_type
  log_destination      = each.value.log_destination_type == "s3" ? (each.value.log_destination == null ? aws_s3_bucket.this[0].arn : each.value.log_destination) : (each.value.log_destination_type == "cloud-watch-logs" ? (each.value.log_destination == null ? aws_cloudwatch_log_group.this[0].arn : each.value.log_destination) : null)
  iam_role_arn         = each.value.log_destination_type == "s3" ? null : (each.value.log_destination_type == "cloud-watch-logs" ? aws_iam_role.cloudwatch_flow_logs_role[0].arn : null)
  log_format           = var.log_format == "" ? null : var.log_format
  tags                 = merge(var.additional_tags, {
    Name         = "vpc-flow-logs-by-Coralogix"
    Terraform-ID = random_string.random.id
  })

}

# If using S3
resource "aws_s3_bucket" "this" {
  count         = local.s3-needed ? 1 : 0
  bucket        = "vpc-flow-logs-${random_string.random.id}"
  force_destroy = true
  tags          = merge(var.additional_tags, {
    Terraform-ID = random_string.random.id
  })
}
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  count  = local.s3-needed ? 1 : 0
  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = length(var.s3_bucket_versioning) > 0 ? var.s3_bucket_versioning : " Disable"
  }
}
resource "aws_s3_bucket_acl" "bucket_acl" {
  count      = local.s3-needed ? 1 : 0
  bucket     = aws_s3_bucket.this[0].id
  acl        = var.s3_bucket_acl
}
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  count  = local.s3-needed && var.s3_bucket_encryption ? 1 : 0
  bucket = aws_s3_bucket.this[0].bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = length(var.kms_master_key_id_for_s3) > 0 ? var.kms_master_key_id_for_s3 : null
      sse_algorithm     = length(var.kms_master_key_id_for_s3) > 0 ? "aws:kms" : "AES256"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  count                   = local.s3-needed ? 1 : 0
  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# If using CloudWatch log group
resource "aws_cloudwatch_log_group" "this" {
  count             = local.cloudwatch-needed ? 1 : 0
  name              = "/aws/vpc/flow-logs-${random_string.random.id}"
  retention_in_days = 1
  kms_key_id        = length(var.kms_master_key_id_for_cloudwatch) > 0 ? var.kms_master_key_id_for_cloudwatch : null
  tags              = merge(var.additional_tags, {
    Terraform-ID = random_string.random.id
  })
}
resource "aws_iam_role" "cloudwatch_flow_logs_role" {
  count = local.cloudwatch-needed ? 1 : 0
  name  = "VPC-Flow-Logs-CloudWatch-Access-${random_string.random.id}"
  tags  = merge(var.additional_tags, {
    Terraform-ID = random_string.random.id
  })
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name   = "aws_flow_logs_policy"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Effect" = "Allow",
          "Action" = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ],
          "Resource" : aws_cloudwatch_log_group.this[0].arn
        }
      ]
    })
  }
}

# Misc
resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
}

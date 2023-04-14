variable "private_key" {
  type      = string
  sensitive = true
}
variable "application_name" {
  type = string
}
variable "subsystem_name" {
  type = string
}
variable "coralogix_domain" {
  type = string
  validation {
    condition     = can(regex("^Europe|Europe2|India|Singapore|US"))
    error_message = "Invalid Coralogix domain."
  }
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}

locals {
  coralogix_domain_map = {
    Europe    = "coralogix.com"
    Europe2   = "eu2.coralogix.com"
    India     = "app.coralogix.in"
    Singapore = "coralogixsg.com"
    US        = "coralogix.us"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "this" {}

resource "aws_lambda_function" "this" {
  function_name = "ECR Findings to Coralogix"
  description   = "Sends ECR image scan findings to Coralogix"
  role          = aws_iam_role.this.arn
  handler       = "python3.9"
  architectures = ["x86_64"]
  timeout       = 300
  s3_bucket     = "snowbit-shared-resources"
  s3_key        = "lambda/ecr-findings.zip"
  environment {
    variables = {
      PRIVATE_KEY      = var.private_key
      APPLICATION_NAME = var.application_name
      SUBSYSTEM_NAME   = var.subsystem_name
      ENDPOINT         = lookup(local.coralogix_domain_map, var.coralogix_domain)
    }
  }
  tags = merge(var.additional_tags, {
    terraform_execution_id = random_string.id.id
  })
}
resource "aws_iam_role" "this" {
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name   = "basic-execution"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Effect"   = "Allow",
          "Action"   = "logs:CreateLogGroup",
          "Resource" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.this.account_id}:*"
        },
        {
          "Effect" = "Allow",
          "Action" = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.this.account_id}:log-group:/aws/lambda/${lower(aws_lambda_function.this.function_name)}:*"
        }
      ]
    })
  }
  inline_policy {
    name   = "ecr-describe-findings"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Effect"   = "Allow",
          "Action"   = "ecr:DescribeImageScanFindings"
          "Resource" = "*"
        }
      ]
    })
  }
}
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}
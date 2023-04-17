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
    condition     = can(regex("^Europe|Europe2|India|Singapore|US", var.coralogix_domain))
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

// Lambda
resource "aws_lambda_layer_version" "requests" {
  layer_name          = "requests"
  s3_bucket           = "snowbit-shared-resources"
  s3_key              = "lambda/layers/requests.zip"
  compatible_runtimes = ["python3.8", "python3.9"]
}
resource "aws_lambda_function" "this" {
  function_name = "ECR-Findings-to-Coralogix-${random_string.this.id}"
  description   = "Sends ECR image scan findings to Coralogix"
  role          = aws_iam_role.this.arn
  handler       = "main.lambda_handler"
  architectures = ["x86_64"]
  runtime       = "python3.8"
  package_type  = "Zip"
  timeout       = 300
  s3_bucket     = "snowbit-shared-resources"
  s3_key        = "lambda/ecr-image-scan.zip"
  layers        = [aws_lambda_layer_version.requests.arn]
  tags          = merge(var.additional_tags, {
    terraform_execution_id = random_string.this.id
  })
  environment {
    variables = {
      PRIVATE_KEY      = var.private_key
      APPLICATION_NAME = var.application_name
      SUBSYSTEM_NAME   = var.subsystem_name
      CORALOGIX_DOMAIN = lookup(local.coralogix_domain_map, var.coralogix_domain)
    }
  }
}
resource "aws_lambda_permission" "invoke" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = "events.amazonaws.com"
  statement_id   = "invoke-${random_string.this.result}"
  source_arn     = aws_cloudwatch_event_rule.this.arn
  source_account = data.aws_caller_identity.this.account_id
}
// EventBridge rule
resource "aws_cloudwatch_event_rule" "this" {
  name          = "ECR-image-scan-lambda-invoke-${random_string.this.id}"
  event_pattern = <<EOF
{
  "source": ["aws.ecr"],
  "detail-type": ["ECR Image Scan"],
  "detail": {
    "scan-status": ["COMPLETE"]
  }
}
EOF
  tags          = merge(var.additional_tags, {
    terraform_execution_id = random_string.this.id
  })
}
resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "eventbridge-target-${random_string.this.id}"
  arn       = aws_lambda_function.this.arn
}
// IAM
resource "aws_iam_role" "this" {
  name               = "Lambda-role-ecr-image-scan-${random_string.this.id}"
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
          "Effect" = "Allow",
          "Action" = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          "Resource" = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.this.account_id}:*",
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.this.account_id}:*:*"

          ]
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
  tags = merge(var.additional_tags, {
    terraform_execution_id = random_string.this.id
  })
}
// Misc
resource "random_string" "this" {
  length  = 6
  upper   = false
  special = false
}

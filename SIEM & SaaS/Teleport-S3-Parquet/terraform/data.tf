data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    sid     = "LambdaAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid    = "ReadTeleportParquet"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      var.events_prefix != ""
      ? "${local.bucket_arn}/${trimsuffix(var.events_prefix, "/")}/*"
      : "${local.bucket_arn}/*",
    ]
  }

  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]

    dynamic "condition" {
      for_each = var.events_prefix != "" ? [trimsuffix(var.events_prefix, "/")] : []
      content {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["${condition.value}/*"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [var.kms_key_arn] : []
    content {
      sid    = "DecryptIfKms"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
      ]
      resources = [statement.value]
    }
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}*",
    ]
  }
}

locals {
  create_ecr = var.image_uri == ""
  image_uri  = local.create_ecr ? "${aws_ecr_repository.this[0].repository_url}:${var.image_tag}" : var.image_uri
  bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.events_bucket}"
}

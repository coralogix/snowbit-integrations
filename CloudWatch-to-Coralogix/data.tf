data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_cloudwatch_log_group" "cloudwatch" {
  name = var.log_group_name
}
data "aws_iam_policy_document" "kms-decrypt" {
  count = length(var.kms_key_arn) > 0 ? 1 : 0
  statement {
    sid       = "kmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}
data "aws_iam_policy_document" "cloudwatch-access" {
  statement {
    sid     = "CloudwatchAccessGeneral"
    effect  = "Allow"
    actions = [
      "logs:GetLogRecord",
      "logs:GetQueryResults",
      "logs:GetLogDelivery"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "CloudwatchAccessSpecificGroup"
    effect    = "Allow"
    actions   = ["logs:Get*"]
    resources = [data.aws_cloudwatch_log_group.cloudwatch.arn]
  }
}
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

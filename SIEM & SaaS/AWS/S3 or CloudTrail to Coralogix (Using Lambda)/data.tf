data "aws_region" "this" {}
data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms-decrypt" {
  count = length(var.kms_id_for_s3) > 0 ? 1 : 0
  statement {
    sid       = "kmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_key.s3[0].arn]
  }
}
data "aws_iam_policy_document" "s3-bucket-access" {
  count = 1
  statement {
    sid     = "s3BucketAccess"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
      "s3:GetLifecycleConfiguration"
    ]
    resources = ["arn:aws:s3:::${var.s3-bucket}", "arn:aws:s3:::${var.s3-bucket}/*"]
  }
}
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "aws_kms_key" "s3" {
  count  = length(var.kms_id_for_s3) > 0 ? 1 : 0
  key_id = var.kms_id_for_s3
}
data "aws_kms_key" "lambda-log-group" {
  count  = length(var.kms_id_for_lambda_log_group) > 0 ? 1 : 0
  key_id = var.kms_id_for_lambda_log_group
}
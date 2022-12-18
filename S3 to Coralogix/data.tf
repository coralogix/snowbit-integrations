data "aws_region" "this" {}
data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms-decrypt" {
  count              = 1
  statement {
    sid              = "kmsDecrypt"
    effect           = "Allow"
    actions          = ["kms:Decrypt"]
    resources        = [var.kms_arn]
  }
}
data "aws_iam_policy_document" "s3-bucket-access" {
  count             = 1
  statement {
    sid             = "s3BucketAccess"
    effect          = "Allow"
    actions         = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
      "s3:GetLifecycleConfiguration"
    ]
    resources       = ["arn:aws:s3:::${var.guardduty-s3-bucket}","arn:aws:s3:::${var.guardduty-s3-bucket}/*"]
  }
}
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

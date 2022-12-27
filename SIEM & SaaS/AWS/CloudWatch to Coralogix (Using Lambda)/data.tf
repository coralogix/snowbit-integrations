data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_cloudwatch_log_group" "cloudwatch" {
  name = var.log_group_name
}
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "aws_kms_key" "kms_key_id_for_lambda_log_group" {
  count = length(var.kms_key_id_for_lambda_log_group) > 0 ? 1 :0
  key_id = var.kms_key_id_for_lambda_log_group
}
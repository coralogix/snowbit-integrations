data "aws_sqs_queue" "sqs_queue" {
  name = var.sqs_queue_name
}
data "aws_caller_identity" "current" {}
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
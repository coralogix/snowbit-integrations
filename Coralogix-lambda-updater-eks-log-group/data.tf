data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "aws_lambda_function" "coralogix_lambda" {
  function_name = var.existing_lambda_to_coralogix_name
}
data "aws_region" "current" {}
data "aws_caller_identity" "id" {}
data "aws_iam_policy_document" "lambda-policy" {
  count = 1
  statement {
    sid     = "lambdaFunction"
    effect  = "Allow"
    actions = [
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy"
    ]
    resources = [data.aws_lambda_function.coralogix_lambda.arn]
  }
}
data "aws_iam_policy_document" "cloud-watch-logs-policy" {
  count = 1
  statement {
    sid     = "lambdaFunction"
    effect  = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:PutSubscriptionFilter",
      "logs:DescribeSubscriptionFilters",
      "logs:DeleteSubscriptionFilter"
    ]
    resources = ["*"]
  }
}
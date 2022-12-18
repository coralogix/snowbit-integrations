resource "aws_lambda_function" "lambda-function" {
  function_name = var.eks_new_lambda_function_name
  filename      = "code.zip"
  timeout       = 60
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda-role.arn
  environment {
    variables = {
      lambda_function_name_to_coralogix = var.existing_lambda_to_coralogix_name
    }
  }
}
resource "aws_lambda_permission" "eventbridge-lambda-invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler.arn
}
resource "aws_iam_role" "lambda-role" {
  name               = "Lambda-Role-${random_id.id.hex}"
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
}
resource "aws_iam_policy" "lambda" {
  name   = "lambda-policy-${random_id.id.hex}"
  policy = data.aws_iam_policy_document.lambda-policy[0].json
}
resource "aws_iam_policy" "cloudwatch" {
  name   = "cloudwatch-policy-${random_id.id.hex}"
  policy = data.aws_iam_policy_document.cloud-watch-logs-policy[0].json
}
resource "aws_iam_policy_attachment" "lambda" {
  name       = "lambdaAttach"
  policy_arn = aws_iam_policy.lambda.arn
  roles      = [aws_iam_role.lambda-role.name]
}
resource "aws_iam_policy_attachment" "cloudwatch" {
  name       = "cloudwatchAttach"
  policy_arn = aws_iam_policy.cloudwatch.arn
  roles      = [aws_iam_role.lambda-role.name]
}
resource "aws_iam_policy_attachment" "AWSLambdaBasicExecutionRole" {
  name       = data.aws_iam_policy.AWSLambdaBasicExecutionRole.name
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
  roles      = [aws_iam_role.lambda-role.name]
}
resource "aws_cloudwatch_event_rule" "scheduler" {
  name                = "lambda-updater-for-eks-shipping"
  schedule_expression = "rate(${var.execution_rate} minutes)"
}
resource "aws_cloudwatch_event_target" "scheduler-target" {
  arn       = aws_lambda_function.lambda-function.arn
  rule      = aws_cloudwatch_event_rule.scheduler.name
  target_id = "lambda-eks-scheduler-target"
}
resource "random_id" "id" {
  byte_length = 4
}

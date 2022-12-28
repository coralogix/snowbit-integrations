# ----------------------------------------------------------
#                        Services
# ----------------------------------------------------------
resource "aws_lambda_function" "cloudwatch-lambda" {
  depends_on    = [aws_cloudwatch_log_group.lambda-log-group]
  function_name = length(var.lambda_application_name) > 0 ? var.lambda_application_name : "CloudWatch-to-Coralogix-${random_id.id.hex}"
  description   = "Send CloudWatch logs to Coralogix"
  handler       = "index.handler"
  runtime       = var.runtime
  architectures = [var.architecture]
  memory_size   = var.memory_size
  timeout       = var.timeout
  role          = aws_iam_role.lambda-role.arn
  s3_bucket     = "coralogix-serverless-repo-${data.aws_region.current.name}"
  s3_key        = "cloudwatch-logs.zip"
  tags          = merge(var.additional_tags,
    {
      Terraform-ID = random_id.id.hex
    })
  environment {
    variables = {
      CORALOGIX_URL         = lookup(var.coralogix_endpoint, var.coralogix_region)
      CORALOGIX_BUFFER_SIZE = tostring(var.buffer_size)
      private_key           = var.private_key
      app_name              = var.application_name
      sub_name              = var.subsystem_name
      newline_pattern       = var.newline_pattern
      buffer_charset        = var.buffer_charset
      sampling              = tostring(var.sampling_rate)
    }
  }
}
resource "aws_lambda_permission" "invoke" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.cloudwatch-lambda.function_name
  principal      = "logs.amazonaws.com"
  statement_id   = "invoke-${random_id.id.hex}"
  source_arn     = "${data.aws_cloudwatch_log_group.cloudwatch.arn}:*"
  source_account = data.aws_caller_identity.current.account_id
}
resource "aws_cloudwatch_log_subscription_filter" "subscription_filter" {
  depends_on      = [aws_lambda_function.cloudwatch-lambda]
  destination_arn = aws_lambda_function.cloudwatch-lambda.arn
  filter_pattern  = ""
  log_group_name  = data.aws_cloudwatch_log_group.cloudwatch.name
  name            = "logs to Coralogix lambda"
}
resource "aws_cloudwatch_log_group" "lambda-log-group" {
  count             = length(var.kms_key_id_for_lambda_log_group) > 0 ? 1 : 0
  name              = "/aws/lambda/${var.lambda_application_name}"
  kms_key_id        = data.aws_kms_key.kms_key_id_for_lambda_log_group[0].arn
  retention_in_days = 1
  tags              = var.additional_tags
}

# ----------------------------------------------------------
#                       Permissions
# ----------------------------------------------------------
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
  tags = merge(var.additional_tags,
    {
      Terraform-ID = random_id.id.hex
    })
}
resource "aws_iam_policy_attachment" "AWSLambdaBasicExecutionRole" {
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
  name       = data.aws_iam_policy.AWSLambdaBasicExecutionRole.name
}

# ----------------------------------------------------------
#                     tf - Metadata
# ----------------------------------------------------------
resource "random_id" "id" {
  byte_length = 4
}

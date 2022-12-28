resource "aws_iam_policy" "kms-policy" {
  count  = length(var.kms_id_for_s3) > 0 ? 1 : 0
  name   = "kms-policy-${random_string.this.result}"
  policy = data.aws_iam_policy_document.kms-decrypt[0].json
  tags   = var.additional_tags
}
resource "aws_iam_policy" "s3-bucket-access" {
  name   = "s3-bucket-access-${random_string.this.result}"
  policy = data.aws_iam_policy_document.s3-bucket-access[0].json
  tags   = var.additional_tags
}
resource "aws_iam_policy_attachment" "kms-policy-attachment" {
  count      = length(var.kms_id_for_s3) > 0 ? 1 : 0
  name       = "kms-policy"
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = aws_iam_policy.kms-policy[0].arn
}
resource "aws_iam_policy_attachment" "s3-policy-attachment" {
  name       = "s3-policy"
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = aws_iam_policy.s3-bucket-access.arn
}
resource "aws_iam_policy_attachment" "AWSLambdaBasicExecutionRole" {
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
  name       = data.aws_iam_policy.AWSLambdaBasicExecutionRole.name
}
resource "aws_iam_role" "lambda-role" {
  name               = "Lambda-Role-${random_string.this.result}"
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
  tags = var.additional_tags
}
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.lambda-role.arn
  s3_bucket     = "coralogix-serverless-repo-${data.aws_region.this.name}"
  s3_key        = "s3.zip"
  runtime       = "nodejs16.x"
  handler       = "index.handler"
  architectures = [var.architecture]
  memory_size   = var.memory_size
  timeout       = var.timeout
  tags          = var.additional_tags
  environment {
    variables = {
      CORALOGIX_URL         = "https://${lookup(local.coralogix_regions, var.coralogix_region, "Europe")}/api/v1/logs"
      CORALOGIX_BUFFER_SIZE = tostring(var.buffer_size)
      private_key           = var.private_key
      app_name              = var.application_name
      sub_name              = var.subsystem_name
      blocking_pattern      = var.blocking_pattern
      debug                 = var.debug
      newline_pattern       = var.newline_pattern
      sampling              = var.sampling_rate
    }
  }
}
resource "random_string" "this" {
  length  = 6
  special = false
  upper   = false
}
resource "aws_lambda_permission" "invoke" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = "s3.amazonaws.com"
  statement_id   = "invoke-${random_string.this.result}"
  source_arn     = "arn:aws:s3:::${var.s3-bucket}"
  source_account = data.aws_caller_identity.current.account_id
}
resource "aws_s3_bucket_notification" "this" {
  bucket = var.s3-bucket
  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_key_prefix
    filter_suffix       = var.s3_key_suffix
  }
}
resource "aws_cloudwatch_log_group" "lambda-execution-log-group" {
  count             = length(var.kms_id_for_lambda_log_group) > 0 ? 1 : 0
  name              = "/aws/lambda/${var.function_name}"
  kms_key_id        = data.aws_kms_key.lambda-log-group[0].arn
  retention_in_days = 1
  tags              = var.additional_tags
}

# ----------------------------------------------------------
#                        Services
# ----------------------------------------------------------
resource "aws_lambda_function" "cloudwatch-lambda" {
  function_name = length(var.lambda_application_name) > 0 ? "${var.lambda_application_name}-${random_id.id.hex}" : "CloudWatch-to-Coralogix-${random_id.id.hex}"
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
  tags          = merge(var.additional_tags,
    {
      Terraform-ID = random_id.id.hex
    })
}
resource "aws_iam_policy" "kms-policy" {
  count  = length(var.kms_key_arn) > 0 ? 1 : 0
  name   = "kms-policy-${random_id.id.hex}"
  policy = data.aws_iam_policy_document.kms-decrypt[0].json
  tags          = merge(var.additional_tags,
    {
      Terraform-ID = random_id.id.hex
    })
}
resource "aws_iam_policy" "cloudwatch-policy" {
  name   = "cloudwatch-access-policy"
  policy = data.aws_iam_policy_document.cloudwatch-access.json
  tags          = merge(var.additional_tags,
    {
      Terraform-ID = random_id.id.hex
    })
}
resource "aws_iam_policy_attachment" "kms-attachment" {
  count      = length(var.kms_key_arn) > 0 ? 1 : 0
  name       = "kms-policy-attach-${random_id.id.hex}"
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = aws_iam_policy.kms-policy[0].arn
}
resource "aws_iam_policy_attachment" "cloudwatch-attachment" {
  name       = "cloudwatch_policy_attach-${random_id.id.hex}"
  policy_arn = aws_iam_policy.cloudwatch-policy.arn
  roles      = [aws_iam_role.lambda-role.name]
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

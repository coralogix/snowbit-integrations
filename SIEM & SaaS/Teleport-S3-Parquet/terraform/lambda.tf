resource "aws_cloudwatch_log_group" "lambda" {
  count             = var.manage_log_group ? 1 : 0
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = local.image_uri
  architectures = ["x86_64"]
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment {
    variables = {
      CORALOGIX_SEND_YOUR_DATA_KEY = var.coralogix_api_key
      CORALOGIX_DOMAIN             = var.coralogix_domain
      CORALOGIX_APPLICATION_NAME   = var.coralogix_application_name
      CORALOGIX_SUBSYSTEM_NAME     = var.coralogix_subsystem_name
      CORALOGIX_BATCH_SIZE         = tostring(var.coralogix_batch_size)
      S3_KEY_PREFIX                = var.events_prefix
      S3_KEY_SUFFIX                = var.events_suffix
      DRY_RUN                      = var.dry_run ? "true" : "false"
      LOG_LEVEL                    = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_lambda_permission" "s3" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = local.bucket_arn
  source_account = data.aws_caller_identity.current.account_id
}

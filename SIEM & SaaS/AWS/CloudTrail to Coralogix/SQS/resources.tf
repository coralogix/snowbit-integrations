resource "aws_lambda_function" "sqs_lambda" {
  function_name = length(var.function_name) > 0 ? var.function_name : "SQS_to_Coralogix-${random_string.id.id}"
  description   = "Sends CloudTrail logs to Coralogix"
  role          = aws_iam_role.lambda_role.arn
  handler       = "function.handler"
  runtime       = "python3.9"
  architectures = ["x86_64"]
  s3_bucket     = "snowbit-shared-resources"
  s3_key        = "lambda/sqs.zip"
  tags          = merge(var.additional_tags,
    {
      execution_id = random_string.id.id
    }
  )
  environment {
    variables = {
      applicationName    = var.application_name
      subsystemName      = var.subsystemName
      coralogix_endpoint = lookup(var.cx_region_map, var.coralogix_region)
      private_key        = var.privateKey
    }
  }
}
resource "aws_lambda_permission" "sqs_invoke" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.sqs_lambda.function_name
  principal      = "sqs.amazonaws.com"
  statement_id   = "invoke-${random_string.id.id}"
  source_arn     = data.aws_sqs_queue.sqs_queue.arn
  source_account = data.aws_caller_identity.current.account_id
}
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}
resource "aws_iam_role" "lambda_role" {
  name               = "Lambda-Role-${random_string.id.id}"
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
      execution_id = random_string.id.id
    }
  )
  inline_policy {
    name   = "sqs_and_s3_permissions"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Sid"    = "sqsPermissions"
          "Effect" = "Allow",
          "Action" = [
            "sqs:DeleteMessage",
            "sqs:ReceiveMessage",
            "sqs:GetQueueAttributes"
          ],
          "Resource" = data.aws_sqs_queue.sqs_queue.arn
        },
        {
          "Sid"    = "S3Permissions"
          "Effect" = "Allow",
          "Action" = [
            "s3:ListBucket",
            "s3:GetObject"
          ]
          "Resource" = [
            "arn:aws:s3:::${var.s3_bucket_to_monitor}",
            "arn:aws:s3:::${var.s3_bucket_to_monitor}/*"
          ]
        }
      ]
    })
  }
}
resource "aws_iam_policy_attachment" "AWSLambdaBasicExecutionRole" {
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
  name       = data.aws_iam_policy.AWSLambdaBasicExecutionRole.name
}
resource "aws_lambda_event_source_mapping" "lambda_event_source_mapping" {
  function_name    = aws_lambda_function.sqs_lambda.arn
  event_source_arn = data.aws_sqs_queue.sqs_queue.arn
  enabled          = true
  batch_size       = 1
}

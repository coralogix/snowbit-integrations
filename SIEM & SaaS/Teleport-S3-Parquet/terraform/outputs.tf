output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "role_arn" {
  value = aws_iam_role.lambda.arn
}

output "ecr_repository_url" {
  value       = local.create_ecr ? aws_ecr_repository.this[0].repository_url : null
  description = "Push the container image here when image_uri was left empty."
}

output "image_uri" {
  value = local.image_uri
}

output "backfill_example" {
  value = "aws lambda invoke --function-name ${aws_lambda_function.this.function_name} --cli-binary-format raw-in-base64-out --payload '{\"bucket\":\"${var.events_bucket}\",\"key\":\"${var.events_prefix}YYYY-MM-DD/file.parquet\"}' /tmp/out.json"
}

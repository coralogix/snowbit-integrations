resource "aws_s3_bucket_notification" "parquet" {
  count  = var.create_s3_notification ? 1 : 0
  bucket = var.events_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.events_prefix != "" ? var.events_prefix : null
    filter_suffix       = var.events_suffix != "" ? var.events_suffix : null
  }

  depends_on = [aws_lambda_permission.s3]
}

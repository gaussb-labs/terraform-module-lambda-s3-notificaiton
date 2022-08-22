locals {
  path_to_binary = "${var.file_path}/${var.file_name}.zip"
}

resource "aws_cloudwatch_log_group" "lambda_s3" {
  name              = "/aws/lambda/${var.environment}_${var.file_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "lambda_s3" {
  filename      = local.path_to_binary
  function_name = "${var.environment}_${var.file_name}"
  handler       = "main"
  runtime       = "go1.x"
  role          = aws_iam_role.iam_for_lambda.arn

  timeout     = var.lambda_timeout
  memory_size = 128

  source_code_hash = filebase64sha256(local.path_to_binary)

  environment {
    variables = merge(var.env_vars, { "ENVIRONMENT" : var.environment })
  }

  depends_on = [
    aws_iam_role_policy.logs,
    aws_iam_role_policy_attachment.lambda_policy
  ]
}

resource "aws_lambda_function_event_invoke_config" "lambda_s3_invoke_config" {
  function_name          = aws_lambda_function.lambda_s3.function_name
  maximum_retry_attempts = 2
}

resource "aws_lambda_permission" "allow_s3_invoke_lambda_s3_papertrail" {
  for_each      = toset(var.bucket_names)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_s3.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${each.value}"
}

resource "aws_s3_bucket_notification" "push_to_lambda_s3_papertrail" {
  for_each = toset(var.bucket_names)
  bucket   = each.value

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_s3.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".log.gz"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_lambda_s3_papertrail]
}
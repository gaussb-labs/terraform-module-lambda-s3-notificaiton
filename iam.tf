locals {
  bucket_arns = [for bucket in toset(var.bucket_names) : "arn:aws:s3:::${bucket}/*"]
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_${var.environment}_${var.file_name}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_role_policy" "logs" {
  name = "${var.environment}_${var.file_name}_logs"
  role = aws_iam_role.iam_for_lambda.name
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:logs:${data.aws_region.current.name}:*:*",
      },
      {
        "Action" : [
          "s3:GetObject",
        ],
        "Effect" : "Allow",
        "Resource" : local.bucket_arns,
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = var.lambda_execution_policy_arn
}

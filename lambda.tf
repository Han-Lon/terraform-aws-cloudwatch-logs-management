# Create a CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "log-management-self-log-group" {
  name = "/aws/lambda/${aws_lambda_function.log-management-lambda.function_name}"

  retention_in_days = var.retention_in_days != "None" ? tonumber(var.retention_in_days) : 7
}

# Zip up the code in lambda_code/log_management.py
data "archive_file" "log-code-zip" {
  source_file = "${path.module}/lambda_code/log_management.py"
  type        = "zip"
  output_path = "${path.module}/lambda_code/log_management.zip"
}

# Deploy the log management Lambda function
resource "aws_lambda_function" "log-management-lambda" {
  function_name = "${local.project}-lambda"
  handler       = "log_management.lambda_handler"
  role          = aws_iam_role.log-management-lambda-role.arn
  runtime       = "python3.9"

  memory_size = var.lambda_memory
  timeout     = var.lambda_timeout

  filename         = data.archive_file.log-code-zip.output_path
  source_code_hash = data.archive_file.log-code-zip.output_base64sha256

  environment {
    variables = {
      CROSS_REGIONS     = var.cross_regions
      RETENTION_IN_DAYS = var.retention_in_days
      KMS_KEY_ALIAS     = var.kms_key_alias
    }
  }
}
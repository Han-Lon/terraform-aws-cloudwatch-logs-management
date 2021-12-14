# Create the CloudWatch event rule that will trigger the log management automation
resource "aws_cloudwatch_event_rule" "log-management-event" {
  name        = "${local.project}-event-rule"
  description = "${local.project} invocation rule"

  schedule_expression = var.invocation_rate
}

# Target the log management Lambda function with the above event rule
resource "aws_cloudwatch_event_target" "log-management-event-target" {
  rule      = aws_cloudwatch_event_rule.log-management-event.name
  target_id = "lambda"
  arn       = aws_lambda_function.log-management-lambda.arn
}

# Allow the event rule in CloudWatch to invoke the log management Lambda function
resource "aws_lambda_permission" "log-managment-invoke-permission" {
  statement_id  = "AllowExecutionFromCloudWatch-${local.project}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log-management-lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.log-management-event.arn
}
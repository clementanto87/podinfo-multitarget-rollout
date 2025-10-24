resource "aws_cloudwatch_metric_alarm" "lambda_error" {
  alarm_name          = "lambda-error-${var.deploy_env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Trigger rollback if lambda errors exceed 1"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.function_name
  }
}
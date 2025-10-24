output "lambda_error_alarm_name" {
  description = "Name of the Lambda error CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_error.alarm_name
}

output "lambda_error_alarm_arn" {
  description = "ARN of the Lambda error CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_error.arn
}
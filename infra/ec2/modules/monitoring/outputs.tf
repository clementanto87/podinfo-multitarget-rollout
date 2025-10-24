output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx.arn
}

output "alb_5xx_alarm_id" {
  description = "ID of the ALB 5xx CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx.id
}

output "alb_5xx_alarm_name" {
  description = "Name of the ALB 5xx CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx.alarm_name
}
output "app_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.lambda.name
}

output "deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.lambda_group.deployment_group_name
}

output "service_role_arn" {
  description = "CodeDeploy service role ARN"
  value       = aws_iam_role.codedeploy_lambda.arn
}
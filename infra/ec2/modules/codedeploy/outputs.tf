output "app_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.ec2.name
}

output "app_id" {
  description = "CodeDeploy application ID"
  value       = aws_codedeploy_app.ec2.id
}

output "deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.ec2_group.deployment_group_name
}

output "deployment_group_id" {
  description = "CodeDeploy deployment group ID"
  value       = aws_codedeploy_deployment_group.ec2_group.id
}

output "service_role_arn" {
  description = "CodeDeploy service role ARN"
  value       = aws_iam_role.codedeploy_ec2_role.arn
}
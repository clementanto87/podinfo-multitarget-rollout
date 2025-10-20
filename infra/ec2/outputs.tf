output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.ec2.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.ec2_group.deployment_group_name
}

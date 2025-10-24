output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb_sg.id
}

output "instance_sg_id" {
  description = "Instance Security Group ID"
  value       = aws_security_group.instance_sg.id
}
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment"
  type        = string
}

variable "asg_name" {
  description = "Auto Scaling Group name"
  type        = string
}

variable "blue_target_group_name" {
  description = "Blue target group name"
  type        = string
}

variable "green_target_group_name" {
  description = "Green target group name"
  type        = string
}

variable "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx CloudWatch alarm"
  type        = string
}
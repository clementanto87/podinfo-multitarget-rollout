variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 2
}

variable "enable_scaling" {
  description = "Enable auto scaling"
  type        = bool
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "instance_sg_id" {
  description = "Instance security group ID"
  type        = string
}

variable "instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}

variable "image_digest" {
  description = "Docker image digest"
  type        = string
}

variable "super_secret_token_arn" {
  description = "ARN of the secret in Secrets Manager"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
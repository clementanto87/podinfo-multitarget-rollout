variable "region" {
  description = "AWS region"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment (dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}

variable "enable_scaling" {
  description = "Enable target tracking scaling"
  type        = bool
  default     = false
}

variable "min_size" {
  type        = number
  default     = 1
}

variable "max_size" {
  type        = number
  default     = 4
}

variable "target_requests_per_target" {
  type        = number
  default     = 100
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}

variable "image_digest" {
  description = "Image digest (sha256:...)"
  type        = string
}

variable "super_secret_token_arn" {
  description = "ARN of secret in Secrets Manager"
  type        = string
}
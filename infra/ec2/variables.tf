# infra/ec2/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "deploy_env" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 2
}

variable "enable_scaling" {
  description = "Enable auto scaling"
  type        = bool
  default     = false
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}

variable "image_digest" {
  description = "Docker image digest (e.g., sha256:...)"
  type        = string
}

variable "super_secret_token_arn" {
  description = "ARN of the secret in AWS Secrets Manager"
  type        = string
}
variable "region" {
  description = "AWS region"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "image_digest" {
  description = "ECR image digest (sha256:...)"
  type        = string
}

variable "ecr_repo_url" {
  description = "Full ECR repository URL (e.g., 123456789012.dkr.ecr.eu-west-1.amazonaws.com/podinfo)"
  type        = string
}

variable "super_secret_token_arn" {
  description = "ARN of the secret in AWS Secrets Manager"
  type        = string
}
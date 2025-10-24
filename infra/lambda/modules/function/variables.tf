variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "image_uri" {
  description = "ECR image URI with digest"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment (dev/staging/prod)"
  type        = string
}

variable "super_secret_token_arn" {
  description = "ARN of the secret in AWS Secrets Manager"
  type        = string
}
variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "function_invoke_arn" {
  description = "Lambda function invoke ARN"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment"
  type        = string
}
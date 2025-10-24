variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "deploy_env" {
  description = "Deployment environment"
  type        = string
}

variable "alarm_names" {
  description = "List of CloudWatch alarm names to monitor"
  type        = list(string)
}
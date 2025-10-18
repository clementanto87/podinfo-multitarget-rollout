variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "terraform_state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "terraform_state_lock_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "terraform-state-locks"
}

variable "github_owner" {
  description = "GitHub organization or username (e.g., your-org)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g., my-app)"
  type        = string
}
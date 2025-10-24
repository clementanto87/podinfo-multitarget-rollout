terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  function_name = "podinfo-${var.deploy_env}"
  ecr_image_uri = "${var.ecr_repo_url}@${var.image_digest}"
}

####################
# ECR Repository Policy
####################
resource "aws_ecr_repository_policy" "lambda_access" {
  repository = "podinfo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "LambdaECRImageRetrievalPolicy"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
    }]
  })
}

####################
# Lambda Function Module
####################
module "function" {
  source = "./modules/function"

  function_name          = local.function_name
  image_uri              = local.ecr_image_uri
  deploy_env             = var.deploy_env
  super_secret_token_arn = var.super_secret_token_arn
}

####################
# API Gateway Module
####################
module "api_gateway" {
  source = "./modules/api-gateway"

  function_name       = module.function.function_name
  function_invoke_arn = module.function.invoke_arn
  deploy_env          = var.deploy_env
}

####################
# Monitoring Module
####################
module "monitoring" {
  source = "./modules/monitoring"

  function_name = module.function.function_name
  deploy_env    = var.deploy_env
}

####################
# CodeDeploy Module
####################
module "codedeploy" {
  source = "./modules/codedeploy"

  function_name = module.function.function_name
  deploy_env    = var.deploy_env
  alarm_names   = [module.monitoring.lambda_error_alarm_name]
}

####################
# Outputs
####################
output "lambda_api_url" {
  value = module.api_gateway.invoke_url
}

output "codedeploy_app_name" {
  value = module.codedeploy.app_name
}

output "codedeploy_deployment_group" {
  value = module.codedeploy.deployment_group_name
}

output "lambda_function_name" {
  value = module.function.function_name
}
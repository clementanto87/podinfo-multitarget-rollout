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
# ECR Repository Policy for Lambda
####################
resource "aws_ecr_repository_policy" "lambda_access" {
  repository = "podinfo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaECRImageRetrievalPolicy"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      }
    ]
  })
}

####################
# Lambda Function
####################
resource "aws_lambda_function" "podinfo" {
  function_name = local.function_name
  package_type  = "Image"
  # Use a stable placeholder image — CodeDeploy will override it
  image_uri     = "${var.ecr_repo_url}@${var.image_digest}"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 15
  memory_size   = 256
  architectures = ["x86_64"]

  environment {
    variables = {
      PORT                  = "9898"
      SUPER_SECRET_TOKEN_ARN = var.super_secret_token_arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_ecr_repository_policy.lambda_access
  ]
}
resource "aws_iam_role" "lambda_exec" {
  name = "podinfo-lambda-exec-${var.deploy_env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

####################
# API Gateway HTTP API
####################
resource "aws_apigatewayv2_api" "http" {
  name          = "podinfo-http-${var.deploy_env}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.podinfo.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

####################
# Permissions
####################
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.podinfo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"

  # Ensure API exists before permission
  depends_on = [aws_apigatewayv2_api.http]
}

####################
# CodeDeploy Canary Setup
####################
resource "aws_codedeploy_app" "lambda" {
  name             = "podinfo-lambda-${var.deploy_env}"
  compute_platform = "Lambda"
}

resource "aws_codedeploy_deployment_group" "lambda_group" {
  app_name               = aws_codedeploy_app.lambda.name
  deployment_group_name  = "lambda-group-${var.deploy_env}"
  service_role_arn       = aws_iam_role.codedeploy_lambda.arn
  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent5Minutes"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled                = true
    alarms                 = [aws_cloudwatch_metric_alarm.lambda_error.alarm_name]
    ignore_poll_alarm_failure = false
  }

}

####################
# IAM Role for CodeDeploy
####################
resource "aws_iam_role" "codedeploy_lambda" {
  name = "codedeploy-lambda-role-${var.deploy_env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

####################
# CloudWatch Alarms
####################
resource "aws_cloudwatch_metric_alarm" "lambda_error" {
  alarm_name          = "lambda-error-${var.deploy_env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Trigger rollback if lambda errors exceed 1"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.podinfo.function_name
  }
}



####################
# Outputs
####################
output "lambda_api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.lambda.name
}

output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.lambda_group.deployment_group_name
}
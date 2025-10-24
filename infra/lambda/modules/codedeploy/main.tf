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
    enabled                   = true
    alarms                    = var.alarm_names
    ignore_poll_alarm_failure = false
  }
}

resource "aws_iam_role" "codedeploy_lambda" {
  name = "codedeploy-lambda-role-${var.deploy_env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}
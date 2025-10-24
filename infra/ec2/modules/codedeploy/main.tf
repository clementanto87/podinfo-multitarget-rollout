####################
# CodeDeploy Application
####################
resource "aws_codedeploy_app" "ec2" {
  name             = "podinfo-ec2-${var.deploy_env}"
  compute_platform = "Server"
}

####################
# CodeDeploy IAM Role
####################
resource "aws_iam_role" "codedeploy_ec2_role" {
  name = "codedeploy-ec2-role-${var.deploy_env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "codedeploy.amazonaws.com" },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "codedeploy-ec2-role-${var.deploy_env}" }
}

resource "aws_iam_role_policy_attachment" "codedeploy_ec2_attach" {
  role       = aws_iam_role.codedeploy_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

####################
# CodeDeploy Deployment Group
####################
resource "aws_codedeploy_deployment_group" "ec2_group" {
  app_name              = aws_codedeploy_app.ec2.name
  deployment_group_name = "ec2-group-${var.deploy_env}"
  service_role_arn      = aws_iam_role.codedeploy_ec2_role.arn

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "CONTINUE_DEPLOYMENT"
      wait_time_in_minutes = 0
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  # ✅ CORRECT: Use target_group_info for ALB
  load_balancer_info {
    target_group_info {
      name = var.blue_target_group_name
    }
    target_group_info {
      name = var.green_target_group_name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms  = [var.alb_5xx_alarm_arn]
  }

  autoscaling_groups = [var.asg_name]
}
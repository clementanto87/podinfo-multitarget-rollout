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
  name_prefix = "podinfo-${var.deploy_env}"
}

####################
# VPC (minimal)
####################
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${local.name_prefix}-public-${count.index}" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${local.name_prefix}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "pub_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

####################
# Security Groups
####################
resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow HTTP from internet"
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name_prefix}-alb-sg" }
}

resource "aws_security_group" "instance_sg" {
  name        = "${local.name_prefix}-instance-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow ALB -> instances"
  ingress {
    from_port       = 9898
    to_port         = 9898
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB to container port"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name_prefix}-instance-sg" }
}

####################
# ALB and Target Groups (blue/green)
####################
resource "aws_lb" "alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb_sg.id]
  tags = { Name = "${local.name_prefix}-alb" }
}

resource "aws_lb_target_group" "blue" {
  name     = "${local.name_prefix}-tg-blue"
  port     = 9898
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${local.name_prefix}-tg-blue" }
}

resource "aws_lb_target_group" "green" {
  name     = "${local.name_prefix}-tg-green"
  port     = 9898
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${local.name_prefix}-tg-green" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

####################
# IAM instance profile for instances (to read secrets)
####################
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${local.name_prefix}-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_secrets" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

####################
# Launch Template (user-data runs docker)
####################
data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.linux.id
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    image_uri    = "${var.ecr_repo_url}@${var.image_digest}"
    secret_arn   = var.super_secret_token_arn
    region       = var.region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-instance"
      DeployEnv   = var.deploy_env
      ImageDigest = var.image_digest
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################
# Auto Scaling Group (desired exactly 2 unless scaling enabled)
####################
resource "aws_autoscaling_group" "asg" {
  name                      = "${local.name_prefix}-asg"
  max_size                  = var.enable_scaling ? var.max_size : var.desired_capacity
  min_size                  = var.enable_scaling ? var.min_size : var.desired_capacity
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = aws_subnet.public[*].id
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  # ⚠️ REMOVED target_group_arns — CodeDeploy manages registration
  # target_group_arns = [...] ← DO NOT include this

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################
# CodeDeploy App + Deployment Group (Server)
####################
resource "aws_codedeploy_app" "ec2" {
  name             = "podinfo-ec2-${var.deploy_env}"
  compute_platform = "Server"
}

resource "aws_iam_role" "codedeploy_ec2_role" {
  name = "codedeploy-ec2-role-${var.deploy_env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Principal = { Service = "codedeploy.amazonaws.com" }, Action = "sts:AssumeRole" }
    ]
  })
  tags = { Name = "codedeploy-ec2-role-${var.deploy_env}" }
}

resource "aws_iam_role_policy_attachment" "codedeploy_ec2_attach" {
  role       = aws_iam_role.codedeploy_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

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
      action                        = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  # ✅ CORRECT: Use target_group_info for ALB
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.blue.name
    }
    target_group_info {
      name = aws_lb_target_group.green.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.alb_5xx.name]
  }
}

####################
# CloudWatch Alarm for ALB 5xxs
####################
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx"
  alarm_description   = "Alarm on ALB target 5xx errors to trigger CodeDeploy rollback"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
  }
  treat_missing_data = "notBreaching"
}

####################
# Optional ASG Target Tracking (scalability improvement)
####################
resource "aws_autoscaling_policy" "req_per_target" {
  count = var.enable_scaling ? 1 : 0
  name  = "${local.name_prefix}-req-per-target"
  resource_id = aws_autoscaling_group.asg.id
  scalable_dimension = "autoscaling:autoScalingGroup:DesiredCapacity"
  service_namespace  = "autoscaling"
  policy_type        = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.alb.arn_suffix}/${aws_lb_target_group.green.arn_suffix}"
    }
    target_value = var.target_requests_per_target
  }
}

####################
# Outputs
####################
output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.ec2.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.ec2_group.deployment_group_name
}
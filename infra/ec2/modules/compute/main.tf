####################
# AMI Data Source
####################
data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

####################
# Launch Template
####################
resource "aws_launch_template" "lt" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.instance_sg_id]
  }

  user_data = base64encode(
    templatefile("./userdata.sh", {
      REGION                 = var.region
      ECR_REPO_URL           = var.ecr_repo_url
      IMAGE_DIGEST           = var.image_digest
      SUPER_SECRET_TOKEN_ARN = var.super_secret_token_arn
    }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.name_prefix}-instance"
      DeployEnv   = var.deploy_env
      ImageDigest = var.image_digest
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################
# Auto Scaling Group
####################
resource "aws_autoscaling_group" "asg" {
  name                      = "${var.name_prefix}-asg"
  max_size                  = var.enable_scaling ? var.max_size : var.desired_capacity
  min_size                  = var.enable_scaling ? var.min_size : var.desired_capacity
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.public_subnets

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
    value               = "${var.name_prefix}-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
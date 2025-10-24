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
# Networking Module
####################
module "networking" {
  source = "./modules/networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
}

####################
# Security Module
####################
module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  vpc_id      = module.networking.vpc_id
}

####################
# Load Balancer Module
####################
module "alb" {
  source = "./modules/alb"

  name_prefix     = local.name_prefix
  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnet_ids
  alb_sg_id       = module.security.alb_sg_id
}

####################
# IAM Module
####################
module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
  deploy_env  = var.deploy_env
}

####################
# Compute Module
####################
module "compute" {
  source = "./modules/compute"

  name_prefix         = local.name_prefix
  deploy_env          = var.deploy_env
  instance_type       = var.instance_type
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  enable_scaling      = var.enable_scaling
  public_subnets      = module.networking.public_subnet_ids
  instance_sg_id      = module.security.instance_sg_id
  instance_profile    = module.iam.instance_profile_name
  ecr_repo_url        = var.ecr_repo_url
  image_digest        = var.image_digest
  super_secret_token_arn = var.super_secret_token_arn
  region              = var.region
}

####################
# CodeDeploy Module
####################
module "codedeploy" {
  source = "./modules/codedeploy"

  name_prefix           = local.name_prefix
  deploy_env            = var.deploy_env
  asg_name              = module.compute.asg_name
  blue_target_group_name = module.alb.blue_target_group_name
  green_target_group_name = module.alb.green_target_group_name
  alb_5xx_alarm_arn     = module.monitoring.alb_5xx_alarm_arn
}

####################
# Monitoring Module
####################
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix    = local.name_prefix
  alb_arn_suffix = module.alb.alb_arn_suffix
}
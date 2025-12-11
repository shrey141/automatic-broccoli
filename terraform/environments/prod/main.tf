# Production Environment - Terraform composition using reusable modules

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "demo-app-terraform-state-files-per-env"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Local values
locals {
  common_tags = {
    Environment = var.environment
    Project     = "demo-app"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "production"
    Compliance  = "required"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Reference the shared ECR repository created in common environment
data "aws_ecr_repository" "demo_app" {
  name = "demo-app"
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 3) # Use 3 AZs for prod
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_flow_logs = true # Enable flow logs for production

  tags = local.common_tags
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  cluster_name              = "${var.environment}-demo-cluster"
  enable_container_insights = true
  use_fargate_spot          = false # Always use regular Fargate for production

  tags = local.common_tags
}

# Application Load Balancer Module
module "alb" {
  source = "../../modules/alb"

  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  public_subnets             = module.networking.public_subnet_ids
  container_port             = 8080
  health_check_path          = "/health"
  enable_deletion_protection = var.enable_deletion_protection # Can be enabled for production safety

  tags = local.common_tags
}

# ECS Service Module
module "ecs_service" {
  source = "../../modules/ecs-service"

  environment              = var.environment
  service_name             = "demo-app"
  cluster_id               = module.ecs_cluster.cluster_id
  cluster_name             = module.ecs_cluster.cluster_name
  vpc_id                   = module.networking.vpc_id
  private_subnets          = module.networking.private_subnet_ids
  target_group_arn         = module.alb.target_group_arn
  alb_security_group_id    = module.alb.alb_security_group_id
  container_image          = "${data.aws_ecr_repository.demo_app.repository_url}:latest"
  container_port           = 8080
  task_cpu                 = var.ecs_task_cpu
  task_memory              = var.ecs_task_memory
  desired_count            = var.ecs_desired_count
  app_version              = var.app_version
  log_retention_days       = 30 # Keep logs longer in production
  autoscaling_min_capacity = var.autoscaling_min_capacity
  autoscaling_max_capacity = var.autoscaling_max_capacity

  tags = local.common_tags

  depends_on = [module.alb]
}

# Observability Module
module "observability" {
  source = "../../modules/observability"

  environment            = var.environment
  service_name           = "demo-app"
  ecs_cluster_name       = module.ecs_cluster.cluster_name
  ecs_service_name       = module.ecs_service.service_name
  alb_arn                = module.alb.alb_arn
  target_group_arn       = module.alb.target_group_arn
  log_group_name         = module.ecs_service.log_group_name
  alert_email            = var.alert_email
  cpu_alarm_threshold    = 70 # More conservative in production
  memory_alarm_threshold = 75
  error_rate_threshold   = 5 # Lower tolerance for errors

  tags = local.common_tags
}

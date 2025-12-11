# Staging Environment - Terraform composition using reusable modules

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "demo-app-terraform-state-files-per-env"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
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
    CostCenter  = "engineering"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_flow_logs = false

  tags = local.common_tags
}

# ECR Module (shared across environments, but shown for completeness)
module "ecr" {
  source = "../../modules/ecr"

  repository_name = "demo-app"
  retention_count = 10 # Keep more images in staging
  scan_on_push    = true

  tags = local.common_tags
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  cluster_name              = "${var.environment}-demo-cluster"
  enable_container_insights = true
  use_fargate_spot          = false # Use regular Fargate for staging

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
  enable_deletion_protection = false # Allow deletion in staging

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
  container_image          = "${module.ecr.repository_url}:latest"
  container_port           = 8080
  task_cpu                 = var.ecs_task_cpu
  task_memory              = var.ecs_task_memory
  desired_count            = var.ecs_desired_count
  app_version              = var.app_version
  log_retention_days       = 14 # Keep logs longer in staging
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 6

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
  cpu_alarm_threshold    = 75
  memory_alarm_threshold = 80
  error_rate_threshold   = 20

  tags = local.common_tags
}

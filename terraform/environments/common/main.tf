# Common Environment - Terraform composition using reusable modules

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after creating S3 bucket and DynamoDB table for state management
  # backend "s3" {
  #   bucket         = "demo-app-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "demo-app-terraform-locks"
  # }
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
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# OIDC Module
module "oidc" {
  source = "../../modules/oidc"

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4eb5fadce486e936c207b5894b425216a4"] # Example thumbprint
  github_owner    = "shrey141"
  github_repo     = "automatic-broccoli"
}

# Terraform State Module
module "tf_state" {
  source = "../../modules/tf-state"

  bucket_name = "demo-app-terraform-state-files-per-env"

  tags = local.common_tags
}


# Platform Engineering Demo - Modern DevOps on AWS

> A production-ready demonstration of modern platform engineering practices featuring containerized applications, infrastructure as code, automated CI/CD, policy as code, and comprehensive observability.

[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange.svg)](https://aws.amazon.com/fargate/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 Overview

This project demonstrates enterprise-scale DevOps and platform engineering practices through a complete, deployable application stack:

- **Application**: Python Flask API with health checks, metrics, and structured logging.
- **Infrastructure**: AWS ECS Fargate with modular Terraform (VPC, ALB, ECS, ECR).
- **CI/CD**: GitHub Actions for automated testing, security scanning, and deployment.
- **Environments**: Isolated `dev` and `prod` environments, plus a `common` environment for shared resources.
- **Observability**: CloudWatch dashboards, metrics, logs, and automated alerting.
- **Security**: OIDC for keyless deployments, multi-layer scanning (container, dependencies, IaC), and policy as code.
- **Scalability**: Auto-scaling, multi-environment support, and reusable components.

## 🏗️ Architecture

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│                     AWS Cloud                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │               Application Load Balancer            │ │
│  │              (Public Subnets - 2 AZs)              │ │
│  └────────────┬───────────────────────┬───────────────┘ │
│               │                       │                 │
│  ┌────────────▼───────────┐ ┌─────────▼──────────────┐  │
│  │   ECS Fargate Task     │ │   ECS Fargate Task     │  │
│  │   (Private Subnet)     │ │   (Private Subnet)     │  │
│  │  ┌──────────────────┐  │ │  ┌──────────────────┐  │  │
│  │  │  Flask App       │  │ │  │  Flask App       │  │  │
│  │  │  - Health checks │  │ │  │  - Health checks │  │  │
│  │  │  - Metrics       │  │ │  │  - Metrics       │  │  │
│  │  │  - Logging       │  │ │  │  - Logging       │  │  │
│  │  └──────────────────┘  │ │  └──────────────────┘  │  │
│  └────────────┬───────────┘ └────────┬───────────────┘  │
│               │                      │                  │
│               ▼                      ▼                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │           CloudWatch (Logs, Metrics, Alarms)       │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  Container Registry: ECR (Shared)                       │
│  Orchestration: ECS Cluster with Auto-scaling           │
│  Networking: VPC with public/private subnets, NAT GW    │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with appropriate permissions to create the resources in this project.
- **Terraform** >= 1.5.0 ([Install](https://www.terraform.io/downloads))
- **Docker** ([Install](https://docs.docker.com/get-docker/))
- **AWS CLI** configured for your account ([Setup](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Python** 3.11+ (for local development)
- **Make** (optional, for convenience commands)

### 1. Bootstrap Shared Resources

First, deploy the `common` environment, which contains shared resources like ECR, the OIDC role for GitHub Actions, and the S3 bucket for Terraform state. This is a one-time setup step.

```bash
# Bootstrap the common environment using the Makefile
make bootstrap-common
```
This command will initialize Terraform, show you the plan, and ask for confirmation before applying.

### 2. Deploy an Environment

Deploy the `dev` or `prod` environments using the CI/CD pipeline or the Makefile.

#### Using GitHub Actions (Recommended)

- **Terraform Deploy (`terraform-deploy.yml`):** Automatically runs on push to `main` (for `dev`) or can be manually triggered to deploy the `prod` environment's infrastructure.
- **Application Deploy (`app-cd.yml`):** Automatically runs on push to `main` (for `dev`) or can be manually triggered to deploy the application to `prod`.

#### Using the Makefile

```bash
# Deploy the dev environment infrastructure
make tf-apply ENV=dev

# Deploy the prod environment infrastructure
make tf-apply ENV=prod
```

### 3. Local Development

You can run the application and tests locally without deploying to AWS.

```bash
# 1. Setup local python environment
make setup

# Activate the virtual environment
cd app && source venv/bin/activate

# 2. Run tests
make test

# 3. Run application locally
make run-dev
```

## 📁 Project Structure

```
.
├── app/                          # Python Flask application
│   ├── src/                      # Application source code
│   ├── tests/                    # Test suite (80%+ coverage)
│   ├── Dockerfile                # Multi-stage production build
│   └── requirements.txt          # Python dependencies
│
├── terraform/                    # Infrastructure as Code
│   ├── modules/                  # Reusable Terraform modules (VPC, ECR, ECS, etc.)
│   └── environments/             # Environment-specific compositions
│       ├── common/               # Shared resources (ECR, OIDC, S3)
│       ├── dev/                  # Development environment
│       └── prod/                 # Production environment
│
├── .github/                      # CI/CD pipelines
│   ├── workflows/                # GitHub Actions workflows
│   └── actions/                  # Reusable composite actions
│
├── docs/                         # Documentation
│
└── Makefile                      # Convenience commands for local dev and deployment
```

## 🌎 Environments

This project uses a multi-environment strategy to isolate resources and manage the deployment lifecycle.

- **`common`**: A special environment that contains shared, foundational resources that are used by other environments. This includes the ECR container registry, the OIDC IAM role for CI/CD, and the S3 bucket for Terraform state. It is deployed once and rarely updated.
- **`dev`**: The development environment. Deploys automatically on every push to the `main` branch, providing a rapid feedback loop for developers. It is configured for cost-savings, using smaller instances and Fargate Spot.
- **`prod`**: The production environment. It is deployed manually or after successful validation in `dev`. It is configured for high availability and reliability, using larger instances, more replicas, and stricter security settings.

## 🛡️ Security

- ✅ **Keyless Deployments with OIDC**: Uses OpenID Connect to establish a trust relationship between GitHub Actions and AWS IAM. This allows workflows to assume an IAM role and get temporary credentials, eliminating the need for long-lived AWS access key secrets.
- ✅ **Container Scanning**: ECR image scanning on push to detect vulnerabilities.
- ✅ **Non-root Containers**: Follows security best practices by running the application as a non-root user.
- ✅ **IAM Least Privilege**: Aims for least-privilege with separate IAM roles for different components (though the demo uses a broad role for simplicity).
- ✅ **Encrypted Storage**: ECR encryption and CloudWatch Logs encryption are enabled.
- ✅ **Restrictive Security Groups**: Default-deny security groups restrict network traffic between resources.

## 🧹 Tear Down

**⚠️ Important**: Tearing down will delete all resources and data. This action cannot be undone.

### Option 1: Automated Pipeline (Recommended)

This repository includes a GitHub Actions workflow to safely destroy infrastructure.

1. Go to the **Actions** tab in GitHub.
2. Select **Destroy Infrastructure** from the workflows list.
3. Click **Run workflow**.
4. Select the environment to destroy (`dev`, `prod`, or `all`).
5. Type `DESTROY` in the confirmation box.
6. Click **Run workflow**.

*Note: Choosing `all` will destroy `dev` and `prod` first, then the `common` environment.*

### Option 2: Manual Utility

If you need to destroy environments manually, use the `make` commands.

```bash
# Destroy the dev environment
make tf-destroy ENV=dev

# Destroy the prod environment
make tf-destroy ENV=prod

# Finally, destroy the common environment
make destroy-common
```
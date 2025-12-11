# Platform Engineering Demo - Modern DevOps on AWS

> A production-ready demonstration of modern platform engineering practices featuring containerized applications, infrastructure as code, automated CI/CD, policy as code, and comprehensive observability.

[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange.svg)](https://aws.amazon.com/fargate/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 Overview

This project demonstrates enterprise-scale DevOps and platform engineering practices through a complete, deployable application stack:

- **Application**: Python Flask API with health checks, metrics, and structured logging
- **Infrastructure**: AWS ECS Fargate with modular Terraform (VPC, ALB, ECS, ECR)
- **CI/CD**: GitHub Actions with reusable workflows and security scanning
- **Observability**: CloudWatch dashboards, metrics, logs, and automated alerting
- **Security**: Multi-layer scanning (container, dependencies, IaC), policy as code
- **Scalability**: Auto-scaling, multi-environment support, reusable components

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
│  ┌────────────▼───────────┐ ┌────────▼───────────────┐  │
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
│  Container Registry: ECR                                │
│  Orchestration: ECS Cluster with Auto-scaling           │
│  Networking: VPC with public/private subnets, NAT GW    │
└─────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **ECS Fargate over EKS**: Simpler operations, no cluster management, faster demo deployment
2. **Modular Terraform**: Reusable modules enable multi-environment deployment with DRY principles
3. **Security-first**: Multiple scanning layers, least-privilege IAM, non-root containers
4. **Cost-optimized**: Fargate Spot for dev, right-sized tasks, log retention policies

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.5.0 ([Install](https://www.terraform.io/downloads))
- **Docker** ([Install](https://docs.docker.com/get-docker/))
- **AWS CLI** configured ([Setup](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Python** 3.11+ (for local development)
- **Make** (optional, for convenience commands)

### Local Development

```bash
# 1. Setup local environment
cd app
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements-dev.txt

# 2. Run tests
pytest tests/ -v --cov=src

# 3. Run application locally
export FLASK_ENV=development
python -m src.app

# 4. Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/api/hello
curl http://localhost:8080/metrics
```

### Build and Test Docker Image

```bash
# Build image
cd app
docker build -t demo-app:local .

# Run container
docker run -p 8080:8080 \
  -e ENVIRONMENT=dev \
  -e ENABLE_CLOUDWATCH=false \
  demo-app:local

# Test health endpoint
curl http://localhost:8080/health
```

### Deploy to AWS

#### Step 1: Setup Terraform Backend (First Time Only)

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://demo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text) --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket demo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name demo-app-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Update backend configuration in terraform/environments/dev/main.tf
# Uncomment the backend "s3" block and update bucket name
```

#### Step 2: Deploy Infrastructure

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply

# Note the outputs (ALB DNS name, ECR repository URL)
```

#### Step 3: Build and Push Docker Image

```bash
# Get ECR repository URL from Terraform outputs
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and tag image
cd ../../../app
docker build -t demo-app:latest .
docker tag demo-app:latest $ECR_REPO:latest
docker tag demo-app:latest $ECR_REPO:v1.0.0

# Push to ECR
docker push $ECR_REPO:latest
docker push $ECR_REPO:v1.0.0
```

#### Step 4: Deploy Application

```bash
# Update ECS service to use new image (will deploy automatically)
cd ../terraform/environments/dev

# Force new deployment
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment \
  --region us-east-1

# Wait for deployment to complete (2-3 minutes)
aws ecs wait services-stable \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --region us-east-1
```

#### Step 5: Test Deployment

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)

# Test endpoints
curl $ALB_URL/health
curl $ALB_URL/api/hello
curl $ALB_URL/api/info

# View in browser
open $ALB_URL/api/hello?name=DevOps
```

### Monitoring

```bash
# View ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --region us-east-1

# View logs (last 10 minutes)
aws logs tail $(terraform output -raw log_group_name) \
  --since 10m \
  --follow \
  --region us-east-1

# View CloudWatch metrics in AWS Console
# Navigate to: CloudWatch > Dashboards > dev-demo-app
```

## 🧹 Tear Down

**⚠️ Important**: Tearing down will delete all resources and data. This action cannot be undone.

### Option 1: Automated Pipeline (Recommended)

This repository includes a GitHub Actions workflow to safely destroy infrastructure.

1. Go to the **Actions** tab in GitHub
2. Select **Destroy Infrastructure** from the workflows list
3. Click **Run workflow**
4. Select the environment to destroy (e.g., `dev`, `staging`, `prod`, `common`, or `all`)
5. Type `DESTROY` in the confirmation box
6. Click **Run workflow**

### Option 2: Manual Utility

```bash
# Navigate to environment directory
cd terraform/environments/dev

# Destroy all infrastructure
terraform destroy

# Optionally, clean up Terraform state backend
aws s3 rb s3://demo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text) --force
aws dynamodb delete-table --table-name demo-app-terraform-locks --region us-east-1
```

## 📁 Project Structure

```
.
├── app/                          # Python Flask application
│   ├── src/
│   │   ├── app.py               # Application factory
│   │   ├── config.py            # Configuration management
│   │   ├── routes/              # API routes
│   │   │   ├── health.py        # Health check endpoints
│   │   │   └── api.py           # Business logic endpoints
│   │   └── middleware/          # Middleware components
│   │       ├── logging.py       # Structured JSON logging
│   │       └── metrics.py       # Prometheus & CloudWatch metrics
│   ├── tests/                   # Test suite (80%+ coverage)
│   ├── Dockerfile               # Multi-stage production build
│   └── requirements.txt         # Python dependencies
│
├── terraform/                    # Infrastructure as Code
│   ├── modules/                 # Reusable Terraform modules
│   │   ├── networking/          # VPC, subnets, NAT, IGW
│   │   ├── ecr/                 # Container registry
│   │   ├── ecs-cluster/         # ECS cluster configuration
│   │   ├── alb/                 # Application Load Balancer
│   │   └── ecs-service/         # ECS service, tasks, auto-scaling
│   │
│   └── environments/            # Environment-specific compositions
│       ├── dev/                 # Development environment
│       ├── staging/             # Staging environment (planned)
│       └── prod/                # Production environment (planned)
│
├── .github/                     # CI/CD pipelines (planned)
│   ├── workflows/               # GitHub Actions workflows
│   └── actions/                 # Reusable composite actions
│
├── docs/                        # Documentation (planned)
│   ├── ARCHITECTURE.md         # Detailed architecture
│   ├── DEPLOYMENT.md           # Deployment guide
│   └── RUNBOOK.md              # Operations runbook
│
└── README.md                    # This file
```

## 🎯 Features & Best Practices

### Application Features

- ✅ **Health Check Endpoints**: `/health`, `/health/ready`, `/health/live` (Kubernetes-style probes)
- ✅ **Metrics Export**: Prometheus `/metrics` endpoint + CloudWatch custom metrics
- ✅ **Structured Logging**: JSON-formatted logs with request IDs and context
- ✅ **12-Factor App**: Environment-based configuration, stateless design
- ✅ **Production WSGI**: Gunicorn with multiple workers
- ✅ **Comprehensive Tests**: 80%+ code coverage with pytest

### Infrastructure Features

- ✅ **Modular Design**: Reusable Terraform modules for all components
- ✅ **Multi-AZ Deployment**: High availability across 2 availability zones
- ✅ **Auto-scaling**: CPU and memory-based scaling (1-4 tasks)
- ✅ **Security Groups**: Least-privilege network access
- ✅ **Private Networking**: Application runs in private subnets
- ✅ **Cost Optimization**: Fargate Spot for dev, right-sized resources

### Security Features

- ✅ **Container Scanning**: ECR image scanning on push
- ✅ **Non-root Containers**: Security best practice
- ✅ **IAM Least Privilege**: Separate task and execution roles
- ✅ **Encrypted Storage**: ECR encryption, CloudWatch Logs encryption
- ✅ **Security Groups**: Restrictive ingress/egress rules
- ✅ **VPC Flow Logs**: Network traffic monitoring (optional)

### Observability Features

- ✅ **CloudWatch Logs**: Centralized application logs
- ✅ **CloudWatch Metrics**: Container Insights + custom metrics
- ✅ **Health Checks**: Multiple levels (container, ECS, ALB)
- ✅ **Request Tracing**: Unique request IDs for correlation
- ✅ **Structured Logging**: Queryable JSON logs

## 🔧 Development

### Running Tests

```bash
cd app

# Run all tests with coverage
pytest tests/ -v --cov=src --cov-report=html

# Run specific test file
pytest tests/unit/test_health.py -v

# Run with markers
pytest -m unit  # Only unit tests
```

### Code Quality

```bash
# Format code
black src/ tests/

# Lint code
flake8 src/ tests/

# Security scanning
bandit -r src/
safety check -r requirements.txt
```

### Local Docker Development

```bash
# Build
docker build -t demo-app:dev -f Dockerfile .

# Run with hot reload (mount source)
docker run -p 8080:8080 \
  -e FLASK_ENV=development \
  -e ENABLE_CLOUDWATCH=false \
  -v $(pwd)/src:/app/src \
  demo-app:dev
```

## 📊 Scalability & Performance

### Auto-scaling Configuration

The ECS service automatically scales based on:
- **CPU Utilization**: Target 70% (scale out at 60s, scale in at 300s)
- **Memory Utilization**: Target 80%
- **Capacity**: Min 1 task, Max 4 tasks

### Performance Tuning

- **Task Resources**: 256 CPU units (0.25 vCPU), 512 MB memory
- **Gunicorn Workers**: 4 workers per task
- **Health Check**: 30s interval, 5s timeout
- **Deregistration Delay**: 30s for graceful shutdown

### Cost Optimization

| Component | Dev Configuration | Annual Cost (est.) |
|-----------|------------------|-------------------|
| ECS Fargate (Spot) | 2 tasks, 256 CPU, 512 MB | ~$130 |
| ALB | 1 ALB | ~$220 |
| NAT Gateway | 2 AZs | ~$720 |
| ECR | < 10 images | ~$1 |
| CloudWatch | Logs + metrics | ~$50 |
| **Total** | | **~$1,121/year** |

**Cost Savings**:
- Use Fargate Spot: 70% savings on compute
- Single NAT Gateway for dev: 50% savings on NAT
- Disable NAT in dev: Additional ~$360/year savings (tasks can't reach internet)

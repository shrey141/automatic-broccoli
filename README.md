# Platform Engineering Demo - Modern DevOps on AWS

> A production-ready demonstration of modern platform engineering practices featuring containerized applications, infrastructure as code, automated CI/CD, policy as code, and comprehensive observability.

[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange.svg)](https://aws.amazon.com/fargate/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [🏗️ Architecture](#️-architecture)
- [🚀 Quick Start](#-quick-start)
- [📁 Project Structure](#-project-structure)
- [🌎 Environments](#-environments)
- [🔄 CI/CD Pipelines](#-cicd-pipelines)
- [📊 Monitoring & Observability](#-monitoring--observability)
- [🛡️ Security](#️-security)
- [🐛 Troubleshooting](#-troubleshooting)
- [💰 Cost Estimates](#-cost-estimates)
- [🧹 Tear Down](#-tear-down)

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

**Expected Output:**
```
✅ ECR repository created
✅ OIDC provider configured for GitHub Actions
✅ S3 bucket created for Terraform state
✅ IAM roles and policies configured
```

**Note:** Running this command again is safe (idempotent) - Terraform will detect existing resources and only make necessary changes.

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

### 3. Access Your Application

After deployment completes, your application will be available at the Application Load Balancer URL.

```bash
# Get the ALB URL for dev environment
cd terraform/environments/dev && terraform output alb_url

# Test the health endpoint
curl $(cd terraform/environments/dev && terraform output -raw alb_url)/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

### 4. Local Development

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

## � CI/CD Pipelines

This project uses GitHub Actions for continuous integration and deployment. All workflows are located in `.github/workflows/`.

### Workflows

#### 1. **CI Pipeline** (`app-ci.yml`)
**Trigger:** Push or Pull Request to `main`

**What it does:**
- Runs linting (flake8, black)
- Executes unit tests with coverage reporting (80%+ required)
- Performs security scanning (Bandit for Python, Trivy for containers)
- Validates Dockerfile and dependencies

**How to view results:**
- Go to the **Actions** tab → Select the workflow run
- Check each job for detailed logs and test results

#### 2. **Terraform Deploy** (`terraform-deploy.yml`)
**Trigger:** 
- Automatic: Push to `main` (deploys to `dev`)
- Manual: Workflow dispatch (can select `dev` or `prod`)

**What it does:**
- Validates Terraform configuration
- Plans infrastructure changes
- Applies changes to the selected environment
- Outputs deployment information (ALB URL, etc.)

**How to manually deploy:**
1. Go to **Actions** → **Terraform Deploy**
2. Click **Run workflow**
3. Select the environment (`dev` or `prod`)
4. Click **Run workflow**

#### 3. **Application Deploy** (`app-cd.yml`)
**Trigger:**
- Automatic: Push to `main` (deploys to `dev`)
- Manual: Workflow dispatch (can select `dev` or `prod`)

**What it does:**
- Builds Docker image
- Scans image for vulnerabilities
- Pushes to ECR
- Updates ECS service with new task definition
- Waits for deployment to stabilize

**How to check deployment status:**
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster platform-demo-dev \
  --services platform-demo-dev \
  --query 'services[0].deployments'
```

#### 4. **Destroy Infrastructure** (`destroy-infra.yml`)
**Trigger:** Manual workflow dispatch only

**What it does:**
- Safely destroys infrastructure in the selected environment
- Requires typing "DESTROY" as confirmation
- Can destroy individual environments or all at once

**Safety features:**
- Manual trigger only (no automatic destruction)
- Confirmation input required
- Destroys environments in the correct order (`dev` → `prod` → `common`)

## 📊 Monitoring & Observability

### CloudWatch Dashboards

Each environment has a CloudWatch dashboard with key metrics:

**Access the dashboard:**
1. Go to AWS Console → CloudWatch → Dashboards
2. Select `platform-demo-{env}-dashboard`

**Key Metrics:**
- **Application Health**: HTTP response codes, request count, latency
- **Container Metrics**: CPU utilization, memory usage, task count
- **Load Balancer**: Target health, connection count, response times

### Logs

Application logs are sent to CloudWatch Logs with structured JSON formatting.

**View logs:**
```bash
# Stream logs for dev environment
aws logs tail /ecs/platform-demo-dev --follow

# Filter for errors
aws logs tail /ecs/platform-demo-dev --follow --filter-pattern "ERROR"

# Search for specific request ID
aws logs filter-log-events \
  --log-group-name /ecs/platform-demo-dev \
  --filter-pattern "request_id=abc123"
```

### Alarms

Automated alarms are configured for:
- **High CPU Usage** (>80% for 5 minutes)
- **High Memory Usage** (>80% for 5 minutes)
- **Unhealthy Targets** (any unhealthy target for 2 minutes)
- **5xx Errors** (>10 errors in 5 minutes)

**Note:** Configure SNS topics in the Terraform variables to receive alarm notifications via email or Slack.

## 🛡️ Security

This project implements multiple layers of security best practices:

### Security Features

- ✅ **Keyless Deployments with OIDC**: Uses OpenID Connect to establish a trust relationship between GitHub Actions and AWS IAM. This allows workflows to assume an IAM role and get temporary credentials, eliminating the need for long-lived AWS access key secrets.
- ✅ **Container Scanning**: ECR image scanning on push to detect vulnerabilities.
- ✅ **Non-root Containers**: Follows security best practices by running the application as a non-root user.
- ✅ **IAM Least Privilege**: Aims for least-privilege with separate IAM roles for different components (though the demo uses a broad role for simplicity).
- ✅ **Encrypted Storage**: ECR encryption and CloudWatch Logs encryption are enabled.
- ✅ **Restrictive Security Groups**: Default-deny security groups restrict network traffic between resources.

### Security Operations

**Review Container Scan Results:**
```bash
# Get latest scan findings for an image
aws ecr describe-image-scan-findings \
  --repository-name platform-demo \
  --image-id imageTag=latest \
  --query 'imageScanFindings.findings[?severity==`CRITICAL` || severity==`HIGH`]'
```

**Review Security Scan Results in CI:**
- Go to **Actions** → Select a workflow run
- Check the **Security Scan** job for Bandit (Python) and Trivy (container) results
- Critical and high-severity findings will fail the build

**Rotate OIDC Trust (if compromised):**
```bash
# Re-deploy the common environment to rotate the OIDC provider
cd terraform/environments/common
terraform taint aws_iam_openid_connect_provider.github
terraform apply
```

**Best Practices:**
- Regularly review and update dependencies
- Monitor CloudWatch Logs for suspicious activity
- Use AWS CloudTrail to audit API calls
- Enable AWS GuardDuty for threat detection (not included in this demo)

## 🐛 Troubleshooting

### Common Issues

#### 1. **Deployment Fails with "Service is unhealthy"**

**Symptoms:** ECS tasks start but fail health checks and are replaced repeatedly.

**Solutions:**
```bash
# Check task logs for errors
aws logs tail /ecs/platform-demo-dev --follow

# Verify health check endpoint is responding
# Get the task's private IP from ECS console, then:
curl http://<task-ip>:5000/health

# Check security group rules allow ALB → Task traffic
aws ec2 describe-security-groups --group-ids <task-sg-id>
```

#### 2. **Terraform Apply Fails with "State Lock Error"**

**Symptoms:** `Error acquiring the state lock` when running Terraform.

**Cause:** Previous Terraform run was interrupted and didn't release the lock.

**Solution:**
```bash
# Force unlock (use the Lock ID from the error message)
cd terraform/environments/dev
terraform force-unlock <LOCK_ID>
```

#### 3. **GitHub Actions Can't Assume IAM Role**

**Symptoms:** `Error: Could not assume role` in GitHub Actions logs.

**Solutions:**
- Verify the OIDC provider is created: `aws iam list-open-id-connect-providers`
- Check the IAM role trust policy includes your GitHub repository
- Ensure the workflow has the correct `permissions: id-token: write`

#### 4. **Container Build Fails with "No Space Left on Device"**

**Symptoms:** Docker build fails during CI/CD.

**Solution:**
```bash
# Clean up Docker resources locally
docker system prune -a --volumes -f

# For GitHub Actions, this is handled automatically
# but you can add a cleanup step if needed
```

#### 5. **High Costs / Unexpected Charges**

**Symptoms:** AWS bill is higher than expected.

**Solutions:**
- Verify NAT Gateway is only in one AZ for dev (check `terraform/environments/dev/main.tf`)
- Ensure you've destroyed unused environments: `make tf-destroy ENV=dev`
- Check for orphaned resources in AWS Console (Load Balancers, EIPs, etc.)
- Review the [Cost Estimates](#-cost-estimates) section

### Getting Help

If you encounter issues not covered here:
1. Check the [GitHub Issues](https://github.com/yourusername/automatic-broccoli/issues) for similar problems
2. Review AWS CloudWatch Logs for detailed error messages
3. Enable Terraform debug logging: `export TF_LOG=DEBUG`

## 💰 Cost Estimates

Understanding the costs associated with running this infrastructure helps you make informed decisions about your deployment strategy.

### Monthly Cost Breakdown (US East Region)

#### Development Environment (`dev`)
| Service | Configuration | Estimated Monthly Cost |
|---------|--------------|----------------------|
| **ECS Fargate** | 2 tasks × 0.25 vCPU, 0.5 GB RAM (Spot) | ~$7 |
| **Application Load Balancer** | 1 ALB with minimal traffic | ~$16 |
| **NAT Gateway** | 1 NAT Gateway (single AZ) | ~$32 |
| **VPC** | Data transfer (estimated 10 GB/month) | ~$1 |
| **CloudWatch** | Logs, metrics, dashboards | ~$5 |
| **ECR** | Storage for container images | ~$1 |
| **S3** | Terraform state storage | <$1 |
| **Total (Dev)** | | **~$62/month** |

#### Production Environment (`prod`)
| Service | Configuration | Estimated Monthly Cost |
|---------|--------------|----------------------|
| **ECS Fargate** | 4 tasks × 0.5 vCPU, 1 GB RAM (On-Demand) | ~$50 |
| **Application Load Balancer** | 1 ALB with moderate traffic | ~$20 |
| **NAT Gateway** | 2 NAT Gateways (multi-AZ) | ~$64 |
| **VPC** | Data transfer (estimated 50 GB/month) | ~$5 |
| **CloudWatch** | Logs, metrics, dashboards, alarms | ~$10 |
| **ECR** | Storage for container images (shared) | Included above |
| **S3** | Terraform state storage (shared) | Included above |
| **Total (Prod)** | | **~$149/month** |

#### Common Environment
| Service | Configuration | Estimated Monthly Cost |
|---------|--------------|----------------------|
| **ECR** | Minimal storage | ~$1 |
| **S3** | Terraform state | <$1 |
| **IAM/OIDC** | No charge | $0 |
| **Total (Common)** | | **~$1/month** |

### Total Estimated Costs
- **Dev Only**: ~$63/month
- **Prod Only**: ~$150/month
- **Both Environments**: ~$212/month

### Cost Optimization Tips

1. **Destroy Dev When Not in Use**: If you're not actively developing, destroy the dev environment to save ~$62/month.
   ```bash
   make tf-destroy ENV=dev
   ```

2. **Use Fargate Spot for Dev**: Already configured in this project. Spot pricing can save up to 70% on compute costs.

3. **Reduce NAT Gateway Costs**: 
   - Dev uses a single NAT Gateway (already optimized)
   - For testing, consider using VPC endpoints for AWS services to reduce data transfer through NAT
   - Alternatively, use a NAT instance instead of NAT Gateway for dev (requires manual setup)

4. **Monitor and Set Budgets**: 
   ```bash
   # Set up AWS Budgets to alert you when costs exceed thresholds
   aws budgets create-budget --account-id <account-id> \
     --budget file://budget.json \
     --notifications-with-subscribers file://notifications.json
   ```

5. **Clean Up Unused Resources**: Regularly check for orphaned resources like old ECR images, unused EBS volumes, or detached Elastic IPs.

**Note:** These are estimates based on typical usage patterns in US East (N. Virginia). Actual costs may vary based on:
- Data transfer volumes
- Number of requests
- Log retention periods
- Your specific AWS region

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
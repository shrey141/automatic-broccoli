# Environment Comparison - Dev vs Production

## Overview

Both environments use the **same Terraform modules** but with different configurations. This demonstrates the DRY principle and shows how infrastructure as code enables environment parity with appropriate environment-specific tuning.

## Quick Comparison Table

| Feature | Dev | Production |
|---------|-----|------------|
| **Purpose** | Development & testing | Live customer traffic |
| **VPC CIDR** | 10.0.0.0/16 | 10.2.0.0/16 |
| **Availability Zones** | 2 | 3 |
| **NAT Gateway** | Yes | Yes |
| **VPC Flow Logs** | No | Yes |
| **Fargate Type** | **Spot** (70% cheaper) | Regular |
| **Task CPU** | 256 (0.25 vCPU) | 1024 (1 vCPU) |
| **Task Memory** | 512 MB | 2048 MB |
| **Desired Tasks** | 2 | 3 |
| **Auto-scaling Min** | 1 | 3 |
| **Auto-scaling Max** | 4 | 10 |
| **Log Retention** | 7 days | 30 days |
| **ECR Repository** | Shared | Shared (30 images) |
| **Deletion Protection** | Disabled | Optional (recommended) |
| **CPU Alarm Threshold** | 80% | 70% |
| **Memory Alarm Threshold** | 85% | 75% |
| **Error Rate Threshold** | 10 errors | 5 errors |
| **Alerts Email** | Optional | **Required** |
| **Deployment Strategy** | Auto (cancel old) | Manual approval |

## Estimated Monthly Costs

### Development Environment
```
ECS Fargate (Spot): 2 tasks × 256 CPU × 512 MB × 730 hrs × $0.01219870 = ~$11/month
ALB:                                                                      ~$18/month
NAT Gateway:        2 AZs × 730 hrs × $0.045 + data                      ~$66/month
CloudWatch:         Logs (7 days) + Metrics + Alarms                    ~$5/month
────────────────────────────────────────────────────────────────────────────────
TOTAL:                                                                   ~$100/month
Note: ECR cost (~$0.60/month) shared across all environments
```

### Production Environment
```
ECS Fargate:        3 tasks × 1024 CPU × 2048 MB × 730 hrs × $0.08097280 = ~$177/month
ALB:                                                                       ~$18/month
NAT Gateway:        3 AZs × 730 hrs × $0.045 + data                       ~$99/month
CloudWatch:         Logs (30 days) + Metrics + Alarms + Dashboards       ~$15/month
VPC Flow Logs:      Storage + queries                                    ~$10/month
────────────────────────────────────────────────────────────────────────────────
TOTAL:                                                                    ~$319/month
```

**Shared Resources:**
```
ECR:                <30 images (shared across all environments)            ~$0.60/month
S3 State Bucket:    Terraform state files                                 ~$0.10/month
────────────────────────────────────────────────────────────────────────────────
```

**Annual Total: (~$420/month × 12) + $8.40 = ~$5,048/year**

## Detailed Differences

### 1. Compute Resources

#### Dev
```hcl
ecs_task_cpu    = 256   # Smallest viable size
ecs_task_memory = 512   # 512 MB
desired_count   = 2     # Minimal HA
use_fargate_spot = true # Cost savings
```
**Rationale:** Developers need fast feedback, not production-level resources. Spot instances are acceptable because downtime doesn't affect customers.

#### Production
```hcl
ecs_task_cpu    = 1024  # Production-grade
ecs_task_memory = 2048  # Generous headroom
desired_count   = 3     # HA across 3 AZs
use_fargate_spot = false # Never spot for production
```
**Rationale:** Over-provision slightly to handle traffic spikes and ensure smooth performance.

### 2. Auto-scaling Behavior

#### Dev
```hcl
autoscaling_min_capacity = 1   # Can scale to 0 tasks if needed
autoscaling_max_capacity = 4   # Limited burst capacity
cpu_target = 70%               # Standard threshold
```
**Behavior:** Aggressive scale-down to save costs. Limited scale-up because dev traffic is low.

#### Production
```hcl
autoscaling_min_capacity = 3   # Always maintain 3 tasks (1 per AZ)
autoscaling_max_capacity = 10  # Significant burst capacity
cpu_target = 70%               # Triggers scaling earlier
```
**Behavior:** Conservative scaling to prevent brownouts. Can handle 3x traffic spikes.

### 3. Observability & Alerting

#### Dev
- **Log Retention:** 7 days (debugging recent issues)
- **CPU Alarm:** 80% (relaxed)
- **Memory Alarm:** 85% (relaxed)
- **Error Rate:** 10 errors/5min (learning environment)
- **Alerts:** Optional (Slack maybe)

#### Production
- **Log Retention:** 30 days (compliance, debugging)
- **CPU Alarm:** 70% (conservative, early warning)
- **Memory Alarm:** 75% (conservative)
- **Error Rate:** 5 errors/5min (low tolerance)
- **Alerts:** PagerDuty/Email (immediate action)
- **Additional:** VPC Flow Logs for security analysis

### 4. Deployment Characteristics

#### Dev
```yaml
concurrency:
  group: deploy-dev
  cancel-in-progress: true  # Cancel old, deploy latest
```
- Deploys automatically on every commit to main
- Cancels in-progress deployments
- No approval required
- Fast feedback loop

#### Production
```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false  # Never cancel
environment:
  name: production
  # requires manual approval
```
- Deploys only after dev success
- Requires manual approval from team
- Queues deployments, never cancels
- Deliberate, controlled releases

### 5. Network Architecture

#### Dev
- **AZs:** 2 (us-east-1a, us-east-1b)
- **NAT Gateways:** 2 (one per AZ)
- **VPC Flow Logs:** Disabled (cost savings)
- **CIDR:** 10.0.0.0/16

#### Production
- **AZs:** 3 (us-east-1a, us-east-1b, us-east-1c)
- **NAT Gateways:** 3 (one per AZ for redundancy)
- **VPC Flow Logs:** Enabled (security auditing)
- **CIDR:** 10.2.0.0/16 (completely isolated)

### 6. Disaster Recovery

#### Dev
- **Backup Strategy:** Terraform state only
- **RTO:** 30 minutes (rebuild from scratch)
- **RPO:** Acceptable data loss (no critical data)
- **Rollback:** Revert git commit

#### Production
- **Backup Strategy:** Terraform state + shared ECR images + logs
- **RTO:** 5 minutes (blue-green deploy)
- **RPO:** No data loss acceptable
- **Rollback:** Instant (previous task definition)

**Note:** ECR repository is shared across all environments and managed in the `common` environment. All environments reference the same container images with different tags.

## Promotion Workflow

### Standard Flow
```
1. Developer commits to feature branch
2. PR created → CI runs (tests, lint, security scan)
3. PR merged to main
   ↓
4. Build Docker image (once)
   ↓
5. Deploy to Dev (automatic)
   ↓ (smoke tests pass)
6. Deploy to Prod (manual approval)
   ↓ (production verification)
7. Monitor CloudWatch dashboards
```

### Hotfix Flow
```
1. Create hotfix branch from main
2. Make minimal fix
3. PR → merge to main
4. Deploy directly to prod with approval
5. Backport to develop
```

## Environment Isolation

### Network Isolation
- Separate VPCs per environment (no peering by default)
- Different CIDR ranges prevent accidental overlap
- Separate security groups and NACLs

### State Isolation
```
S3 Backend Structure:
demo-app-terraform-state/
  ├── dev/terraform.tfstate
  └── prod/terraform.tfstate

DynamoDB Locks:
demo-app-terraform-locks
  ├── dev/terraform.tfstate-md5
  └── prod/terraform.tfstate-md5
```

### Secrets Isolation
```
GitHub Environments:
- dev → DEV_AWS_ROLE_ARN
- production → PROD_AWS_ROLE_ARN (with approvals)
```

## Cost Optimization Strategies

### Dev Environment
- ✅ Use Fargate Spot (70% savings)
- ✅ Scale to 1 task during off-hours
- ✅ Short log retention (7 days)
- ✅ Consider stopping overnight (additional 66% savings)

### Production Environment
- ✅ Use Savings Plans for predictable baseline
- ✅ Right-size based on actual metrics (CloudWatch)
- ✅ Use CloudWatch Logs Insights instead of exporting all logs
- ⚠️ Never compromise reliability for cost

## When to Use Which Environment

### Use Dev For:
- ✅ Active development
- ✅ Feature testing
- ✅ Breaking changes
- ✅ Experimentation
- ✅ Learning new tools

### Use Production For:
- ✅ Live customer traffic only
- ⛔ Never for testing
- ⛔ Never for experiments
- ⛔ Never without approval

## Terraform Commands by Environment

```bash
# Dev
make tf-init ENV=dev
make tf-plan ENV=dev
make tf-apply ENV=dev
make deploy ENV=dev

# Production
make tf-init ENV=prod
make tf-plan ENV=prod
make tf-apply ENV=prod
make deploy ENV=prod  # Will fail without manual approval in GitHub Actions
```
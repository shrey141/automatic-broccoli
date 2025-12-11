# Environment Comparison - Dev vs Staging vs Production

## Overview

All three environments use the **same Terraform modules** but with different configurations. This demonstrates the DRY principle and shows how infrastructure as code enables environment parity with appropriate environment-specific tuning.

## Quick Comparison Table

| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| **Purpose** | Development & testing | Pre-production validation | Live customer traffic |
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Availability Zones** | 2 | 2 | 3 |
| **NAT Gateway** | Yes | Yes | Yes |
| **VPC Flow Logs** | No | No | Yes |
| **Fargate Type** | **Spot** (70% cheaper) | Regular | Regular |
| **Task CPU** | 256 (0.25 vCPU) | 512 (0.5 vCPU) | 1024 (1 vCPU) |
| **Task Memory** | 512 MB | 1024 MB | 2048 MB |
| **Desired Tasks** | 2 | 2 | 3 |
| **Auto-scaling Min** | 1 | 2 | 3 |
| **Auto-scaling Max** | 4 | 6 | 10 |
| **Log Retention** | 7 days | 14 days | 30 days |
| **ECR Image Retention** | 5 images | 10 images | 30 images |
| **Deletion Protection** | Disabled | Disabled | Optional (recommended) |
| **CPU Alarm Threshold** | 80% | 75% | 70% |
| **Memory Alarm Threshold** | 85% | 80% | 75% |
| **Error Rate Threshold** | 10 errors | 20 errors | 5 errors |
| **Alerts Email** | Optional | Recommended | **Required** |
| **Deployment Strategy** | Auto (cancel old) | Auto (queued) | Manual approval |

## Estimated Monthly Costs

### Development Environment
```
ECS Fargate (Spot): 2 tasks × 256 CPU × 512 MB × 730 hrs × $0.01219870 = ~$11/month
ALB:                                                                      ~$18/month
NAT Gateway:        2 AZs × 730 hrs × $0.045 + data                      ~$66/month
ECR:                <5 images                                            ~$0.10/month
CloudWatch:         Logs (7 days) + Metrics + Alarms                    ~$5/month
────────────────────────────────────────────────────────────────────────────────
TOTAL:                                                                   ~$100/month
```

### Staging Environment
```
ECS Fargate:        2 tasks × 512 CPU × 1024 MB × 730 hrs × $0.04048640 = ~$59/month
ALB:                                                                      ~$18/month
NAT Gateway:        2 AZs                                                ~$66/month
ECR:                <10 images                                           ~$0.20/month
CloudWatch:         Logs (14 days) + Metrics + Alarms                   ~$8/month
────────────────────────────────────────────────────────────────────────────────
TOTAL:                                                                   ~$151/month
```

### Production Environment
```
ECS Fargate:        3 tasks × 1024 CPU × 2048 MB × 730 hrs × $0.08097280 = ~$177/month
ALB:                                                                       ~$18/month
NAT Gateway:        3 AZs × 730 hrs × $0.045 + data                       ~$99/month
ECR:                <30 images                                            ~$0.60/month
CloudWatch:         Logs (30 days) + Metrics + Alarms + Dashboards       ~$15/month
VPC Flow Logs:      Storage + queries                                    ~$10/month
────────────────────────────────────────────────────────────────────────────────
TOTAL:                                                                    ~$320/month
```

**Annual Total: ~$571/month × 12 = ~$6,852/year**

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

#### Staging
```hcl
ecs_task_cpu    = 512   # 2x dev
ecs_task_memory = 1024  # 2x dev
desired_count   = 2     # Same as prod start
use_fargate_spot = false # Reliability for testing
```
**Rationale:** Should mirror production characteristics for realistic testing, but doesn't need full production scale.

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

#### Staging
```hcl
autoscaling_min_capacity = 2   # Always maintain 2 tasks
autoscaling_max_capacity = 6   # Moderate burst capacity
cpu_target = 70%               # Standard threshold
```
**Behavior:** Maintains minimum HA, can handle moderate load testing.

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

#### Staging
- **Log Retention:** 14 days (investigate test failures)
- **CPU Alarm:** 75% (moderate)
- **Memory Alarm:** 80% (moderate)
- **Error Rate:** 20 errors/5min (stress testing expected)
- **Alerts:** Email to team

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

#### Staging
```yaml
concurrency:
  group: deploy-staging
  cancel-in-progress: false  # Queue deployments
```
- Deploys automatically after dev success
- Queues multiple deployments (tests all commits)
- No approval required
- Validates before production

#### Production
```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false  # Never cancel
environment:
  name: production
  # requires manual approval
```
- Deploys only after staging success
- Requires manual approval from team
- Queues deployments, never cancels
- Deliberate, controlled releases

### 5. Network Architecture

#### Dev
- **AZs:** 2 (us-east-1a, us-east-1b)
- **NAT Gateways:** 2 (one per AZ)
- **VPC Flow Logs:** Disabled (cost savings)
- **CIDR:** 10.0.0.0/16

#### Staging
- **AZs:** 2 (us-east-1a, us-east-1b)
- **NAT Gateways:** 2 (one per AZ)
- **VPC Flow Logs:** Disabled (cost savings)
- **CIDR:** 10.1.0.0/16 (separate from dev)

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

#### Staging
- **Backup Strategy:** Terraform state + ECR images
- **RTO:** 15 minutes (redeploy)
- **RPO:** Minimal data loss
- **Rollback:** Previous image tag

#### Production
- **Backup Strategy:** Terraform state + ECR images + logs
- **RTO:** 5 minutes (blue-green deploy)
- **RPO:** No data loss acceptable
- **Rollback:** Instant (previous task definition)

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
6. Deploy to Staging (automatic)
   ↓ (integration tests pass)
7. Deploy to Prod (manual approval)
   ↓ (production verification)
8. Monitor CloudWatch dashboards
```

### Hotfix Flow
```
1. Create hotfix branch from main
2. Make minimal fix
3. PR → merge to main
4. Optional: Skip staging with workflow_dispatch
5. Deploy directly to prod with approval
6. Backport to develop
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
  ├── staging/terraform.tfstate
  └── prod/terraform.tfstate

DynamoDB Locks:
demo-app-terraform-locks
  ├── dev/terraform.tfstate-md5
  ├── staging/terraform.tfstate-md5
  └── prod/terraform.tfstate-md5
```

### Secrets Isolation
```
GitHub Environments:
- dev → DEV_AWS_ROLE_ARN
- staging → STAGING_AWS_ROLE_ARN
- production → PROD_AWS_ROLE_ARN (with approvals)
```

## Cost Optimization Strategies

### Dev Environment
- ✅ Use Fargate Spot (70% savings)
- ✅ Scale to 1 task during off-hours
- ✅ Short log retention (7 days)
- ✅ Consider stopping overnight (additional 66% savings)

### Staging Environment
- ✅ Use Reserved Capacity if running 24/7
- ✅ Scale to minimum during off-hours
- ⚠️ Don't use Spot (need reliability for testing)

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

### Use Staging For:
- ✅ Final validation before production
- ✅ Performance testing
- ✅ Integration testing
- ✅ Security testing
- ✅ Customer demos (maybe)

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

# Staging
make tf-init ENV=staging
make tf-plan ENV=staging
make tf-apply ENV=staging
make deploy ENV=staging

# Production
make tf-init ENV=prod
make tf-plan ENV=prod
make tf-apply ENV=prod
make deploy ENV=prod  # Will fail without manual approval in GitHub Actions
```

## Interview Talking Points

1. **"Show me how you handle multiple environments"**
   - Point to this document
   - Explain module reusability
   - Show terraform.tfvars differences
   - Discuss cost vs. reliability tradeoffs

2. **"How do you ensure environment parity?"**
   - Same Docker image promoted through all environments
   - Same Terraform modules with different variables
   - Configuration as code (no manual changes)

3. **"How do you optimize costs?"**
   - Fargate Spot in dev saves 70%
   - Right-sizing based on actual usage
   - Shorter log retention in non-prod
   - Auto-scaling prevents over-provisioning

4. **"What's your deployment strategy?"**
   - Progressive delivery (dev → staging → prod)
   - GitHub Environments with approval gates
   - Same image tag promoted through environments
   - Rollback capability at each stage

## Summary

This multi-environment setup demonstrates:
- ✅ **DRY Principles:** Same modules, different values
- ✅ **Cost Optimization:** Appropriate sizing per environment
- ✅ **Risk Management:** Progressive delivery with gates
- ✅ **Platform Engineering:** Reusable, scalable patterns
- ✅ **Production Thinking:** Proper observability and alerting

All three environments are ready to deploy using the same Terraform modules with environment-specific variable files.

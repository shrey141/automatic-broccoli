# CD Pipeline Strategy - GitHub Environments

## Architecture Decision: Chained Deployments with Concurrency Controls

### ✅ Recommended Approach: Progressive Delivery Pipeline

```
┌──────────┐     ┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  Build   │ ──> │  Deploy Dev │ ──> │ Deploy Stage │ ──> │ Deploy Prod│
│ (1 image)│     │  (automatic)│     │  (automatic) │     │  (manual)  │
└──────────┘     └─────────────┘     └──────────────┘     └────────────┘
                       ↓                    ↓                    ↓
                 Smoke Tests          Integration Tests    Full Tests
```

### Key Design Decisions

#### 1. **Single Build, Multiple Deploys**
- ✅ Build Docker image **once** at the start
- ✅ Same image promoted through all environments
- ✅ Ensures environment parity
- ✅ Faster deployments (no rebuild)

#### 2. **GitHub Environments for Promotion**
```yaml
environment:
  name: production
  url: ${{ steps.deploy.outputs.url }}
```

**Benefits:**
- **Protection Rules**: Require approvals before prod
- **Environment Secrets**: Separate credentials per environment
- **Deployment History**: Track what's deployed where
- **Branch Policies**: Restrict which branches can deploy
- **Wait Timers**: Optional delays before deployment

**Configuration in GitHub:**
```
Settings > Environments > [Create Environment]

Production:
  ✅ Required reviewers: @platform-team
  ✅ Wait timer: 5 minutes
  ✅ Branch protection: main only
  ✅ Secrets: PROD_AWS_ROLE_ARN

Staging:
  ✅ Auto-deploy from main
  ⬜ No approvals needed

Dev:
  ✅ Auto-deploy from main
  ✅ Cancel in-progress runs
```

#### 3. **Concurrency Controls - The Critical Part**

**Problem:** Multiple commits to `main` cause race conditions

**Solution:** Different strategies per environment

```yaml
# DEV - Cancel old, deploy latest
deploy-dev:
  concurrency:
    group: deploy-dev
    cancel-in-progress: true  # ✅ Fast feedback, latest code

# STAGING - Queue deployments
deploy-staging:
  concurrency:
    group: deploy-staging
    cancel-in-progress: false  # ✅ Test every build

# PROD - Queue and protect
deploy-prod:
  concurrency:
    group: deploy-prod
    cancel-in-progress: false  # ✅ Never cancel production
```

**Why Different Strategies?**

| Environment | Strategy | Reasoning |
|-------------|----------|-----------|
| **Dev** | Cancel old | Developers want latest code ASAP. Old deploys are wasted. |
| **Staging** | Queue | Need to test every build before prod. Can't skip. |
| **Prod** | Queue + Manual | Every deployment is deliberate. Can't cancel. |

### Alternative Approaches Considered

#### ❌ Option A: Parallel Deployments (Not Recommended)
```yaml
jobs:
  deploy:
    strategy:
      matrix:
        environment: [dev, staging, prod]
```

**Problems:**
- All environments deploy simultaneously
- Can't test staging before prod
- No promotion workflow
- Risk of deploying broken code to prod

#### ❌ Option B: Separate Workflows per Environment
```
.github/workflows/deploy-dev.yml
.github/workflows/deploy-staging.yml
.github/workflows/deploy-prod.yml
```

**Problems:**
- Duplication of deployment logic
- Hard to maintain consistency
- Can't chain dependencies
- Manual promotion needed

#### ⚠️ Option C: workflow_run Triggers
```yaml
on:
  workflow_run:
    workflows: ["Deploy to Staging"]
    types: [completed]
```

**Pros:**
- Automatic chaining
- Clear separation

**Cons:**
- Complex to debug
- Difficult to pass artifacts
- Can't cancel previous environment
- Less visibility in GitHub UI

### ✅ Our Choice: Chained Jobs with Environments

```yaml
jobs:
  build:
    # Build once, outputs image tag

  deploy-dev:
    needs: build
    environment: dev
    concurrency:
      group: deploy-dev
      cancel-in-progress: true

  deploy-staging:
    needs: [build, deploy-dev]  # Chains after dev
    environment: staging
    concurrency:
      group: deploy-staging
      cancel-in-progress: false

  deploy-prod:
    needs: [build, deploy-staging]  # Chains after staging
    environment: production  # Manual approval required
    concurrency:
      group: deploy-prod
      cancel-in-progress: false
```

**Benefits:**
1. ✅ **Progressive Delivery**: Must pass dev → staging → prod
2. ✅ **Single Workflow**: All logic in one place
3. ✅ **Concurrency Control**: Prevent race conditions
4. ✅ **Fast Feedback**: Dev deployments don't wait
5. ✅ **Safety**: Prod requires approval + staging success
6. ✅ **Visibility**: One view shows entire pipeline
7. ✅ **Artifact Sharing**: Image tag passes between jobs

### Handling Multiple Commits

#### Scenario: 3 commits pushed quickly to main

**Without Concurrency Control:**
```
Commit A: dev → staging → prod (deploying)
Commit B: dev → staging → prod (deploying)  ❌ Race condition!
Commit C: dev → staging → prod (deploying)  ❌ Out of order!
```

**With Our Strategy:**
```
Commit A: dev → staging → prod ✅
Commit B: dev (cancels A's dev) → staging (queued) → prod (queued) ✅
Commit C: dev (cancels B's dev) → staging (queued) → prod (queued) ✅

Result:
- Dev: Only C deploys (latest)
- Staging: A, B, C deploy in order (all tested)
- Prod: Manual approval for each (safe)
```

### Advanced: Conditional Deployment

Sometimes you don't want to deploy to all environments:

```yaml
deploy-prod:
  if: |
    github.event_name == 'workflow_dispatch' ||
    contains(github.event.head_commit.message, '[deploy-prod]')
```

**Use cases:**
- Only deploy to prod on manual trigger
- Skip environments based on commit message
- Deploy hotfixes directly to prod (emergency)

### Monitoring & Observability

**Deployment Dashboard:**
```yaml
- name: Post deployment metrics
  run: |
    aws cloudwatch put-metric-data \
      --namespace "Deployments" \
      --metric-name "DeploymentSuccess" \
      --value 1 \
      --dimensions Environment=${{ matrix.environment }}
```

**Slack Notifications:**
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Deployed ${{ github.sha }} to ${{ environment }}",
        "status": "${{ job.status }}"
      }
```

### Rollback Strategy

**Option 1: Redeploy Previous Image**
```bash
# In GitHub Actions
aws ecs update-service \
  --task-definition $PREVIOUS_TASK_DEFINITION \
  --force-new-deployment
```

**Option 2: Revert Git Commit**
```bash
git revert HEAD
git push origin main
# Triggers automatic deployment
```

**Option 3: Manual Workflow Dispatch**
```yaml
workflow_dispatch:
  inputs:
    image-tag:
      description: 'Image tag to deploy'
      required: true
```

### Cost Considerations

**Workflow Minutes:**
- Build: ~5 minutes
- Deploy per environment: ~3 minutes
- Total per push to main: ~14 minutes

**Optimization:**
- Cache Docker layers: Save 2-3 minutes
- Use GitHub's larger runners for build: Faster but costs more
- Skip staging for feature branches: Save minutes

### Security Best Practices

1. **OIDC instead of static credentials:**
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # OIDC
    # No access keys stored!
```

2. **Environment-specific secrets:**
- `DEV_AWS_ROLE_ARN`
- `STAGING_AWS_ROLE_ARN`
- `PROD_AWS_ROLE_ARN`

3. **Approval gates:**
- Production requires team approval
- Staging auto-deploys after dev success
- Dev auto-deploys on every commit

### Comparison Table

| Approach | Promotion | Concurrency | Visibility | Complexity | Recommended |
|----------|-----------|-------------|------------|------------|-------------|
| **Chained Jobs + Environments** | ✅ Automatic | ✅ Per-env | ✅ Single view | Low | ✅ **YES** |
| Parallel Matrix | ❌ None | ❌ All together | ⚠️ Scattered | Low | ❌ No |
| Separate Workflows | ⚠️ Manual | ✅ Per-workflow | ❌ Multiple views | High | ❌ No |
| workflow_run | ✅ Automatic | ⚠️ Complex | ❌ Separate | Medium | ⚠️ Maybe |

### Conclusion

**Use GitHub Environments with chained jobs and per-environment concurrency controls.**

This approach:
- ✅ Prevents race conditions
- ✅ Enables progressive delivery
- ✅ Provides fast feedback (dev)
- ✅ Ensures quality (staging)
- ✅ Protects production (manual approval)
- ✅ Scales to multiple teams
- ✅ Easy to understand and maintain

### Next Steps

1. Set up GitHub Environments in repo settings
2. Configure AWS OIDC for GitHub Actions
3. Add required reviewers for production
4. Test with a small change
5. Add Slack/email notifications
6. Set up deployment dashboards

## Resources

- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Concurrency Controls](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#concurrency)
- [AWS OIDC for GitHub](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

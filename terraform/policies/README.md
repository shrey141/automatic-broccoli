# Policy as Code - Terraform Security & Compliance

This directory contains automated policy checks for Terraform infrastructure code using **Checkov** for AWS best practices and security checks.

## 🎯 Purpose

Policy as Code ensures:
- ✅ **Security**: Prevent insecure configurations before deployment
- ✅ **Compliance**: Enforce organizational standards automatically
- ✅ **Cost Control**: Catch expensive misconfigurations early
- ✅ **Consistency**: Same rules across all environments
- ✅ **Shift-Left**: Find issues in PR review, not in production

## 📁 Directory Structure

```text
 terraform/policies/
 ├── checkov/
 │   └── .checkov.yaml          # Checkov configuration
 └── README.md                  # This file
```

## 🔧 Checkov - AWS Security Best Practices

### What Checkov Checks

Checkov scans for **30+ AWS security best practices**, including:

**ECS Security:**
- ✅ Task definitions have memory/CPU limits
- ✅ Containers run as non-root users
- ✅ Data encrypted in transit

**IAM Security:**
- ✅ No wildcard permissions (`*:*`)
- ✅ No overly permissive policies
- ✅ Policies attached to roles, not users

**Network Security:**
- ✅ Security groups have descriptions
- ✅ No unrestricted SSH (0.0.0.0/0:22)
- ✅ No unrestricted RDP (0.0.0.0/0:3389)

**CloudWatch & Logging:**
- ✅ Log groups encrypted at rest
- ✅ Log retention policies set

**ECR Security:**
- ✅ Image scanning enabled
- ✅ KMS encryption enabled

### Configuration

See `.checkov.yaml` for the complete configuration.

**Key settings:**
```yaml
framework: terraform
soft-fail: true  # Warning mode (change to false for strict enforcement)
check: [CKV_AWS_8, CKV_AWS_111, ...]  # Specific checks to run
skip-check: [CKV_AWS_2, ...]          # Checks to skip (with justification)
```

### Running Checkov Locally

```bash
# Install
pip install checkov

# Scan all Terraform
checkov -d terraform/ --config-file terraform/policies/checkov/.checkov.yaml

# Scan specific environment
checkov -d terraform/environments/dev --config-file terraform/policies/checkov/.checkov.yaml

# Get JSON output
checkov -d terraform/ --config-file terraform/policies/checkov/.checkov.yaml --output json

# Use Makefile
make scan-iac
```

### Example Output

```
Check: CKV_AWS_8: "Ensure ECS task definition has memory limit"
	PASSED for resource: aws_ecs_task_definition.main
	File: /terraform/modules/ecs-service/main.tf:85-150

Check: CKV_AWS_111: "Ensure IAM policies does not allow write access without constraints"
	FAILED for resource: aws_iam_role_policy.bad_policy
	File: /terraform/modules/ecs-service/main.tf:200-215
	Guide: https://docs.bridgecrew.io/docs/iam_write_access_without_constraint

	85 | resource "aws_iam_role_policy" "bad_policy" {
	86 |   policy = {
	87 |     Action = "*"        # ❌ Wildcard permissions
	88 |     Resource = "*"      # ❌ All resources
	89 |   }
	90 | }
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The `.github/workflows/terraform-plan.yml` workflow automatically runs Checkov:

```yaml
jobs:
  checkov:
    - Install Checkov
    - Scan all Terraform code
    - Comment results on PR

  plan:
    - Generate Terraform plan
    - Comment plan on PR
```

### Workflow Triggers

```yaml
on:
  pull_request:
    paths: ['terraform/**']  # Only when Terraform changes
  push:
    branches: [main]
```

### Policy Enforcement Strategy

| Tool | Mode | Action on Violation |
|------|------|---------------------|
| **Checkov** | Soft-fail | ⚠️ Warning (doesn't block merge) |
| **Terraform Validate** | Hard-fail | ❌ Blocks merge |

**Rationale:**
- **Checkov** in soft-fail mode because some checks are aspirational (e.g., HTTPS, which we'll add later)
- Can flip Checkov to hard-fail for production: `soft-fail: false`

## 📊 Policy Coverage

### Current Policy Count

- **Checkov Checks:** 30+ enabled
- **Total Coverage:** 30+ automated checks

### Policy Categories

| Category | Checkov |
|----------|---------|
| ECS Security | 3 |
| IAM Security | 8 |
| Network Security | 6 |
| Logging | 2 |
| ALB/ELB | 4 |
| S3 | 5 |
| ECR | 2 |

## 🔒 Security Best Practices

### 1. Keep Policies Updated
```bash
# Update Checkov regularly
pip install --upgrade checkov
```

### 2. Review Policy Violations
- Don't blindly skip checks
- Document why in `.checkov.yaml`
- Get security team approval

### 3. Test Before Enforcing
- Start with soft-fail mode
- Monitor false positive rate
- Gradually enable hard-fail

### 4. Version Control Policies
- Treat policies as code
- Review changes in PRs
- Test policy changes

## 📈 Metrics & Reporting

### View Policy Trends

```bash
# Count violations over time
checkov -d terraform/ --output json | jq '.summary'

# Generate HTML report
checkov -d terraform/ --output html --output-file report.html
```

### Integration with Security Tools

Checkov supports SARIF output for GitHub Security:

```yaml
- name: Upload Checkov SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: checkov.sarif
```

## 🎤 Interview Talking Points

**"Tell me about your policy as code implementation"**

> "I use Checkov to catch 30+ security issues like missing encryption or overly permissive IAM policies. It runs automatically in CI/CD in warning mode, allowing developers to see issues without blocking them. This 'paved road' approach guides developers toward secure patterns while keeping them productive."

**"How do you balance security with developer velocity?"**

> "I use soft-fail mode for Checkov initially, allowing developers to see issues without blocking them. We document all skipped checks with justifications in the config file. For production deployments, we can enable hard-fail mode to enforce critical security requirements."

**"How does this integrate with your CI/CD pipeline?"**

> "Checkov runs on every PR that modifies Terraform code. It automatically comments the scan results on the PR, showing passed, failed, and skipped checks. This gives immediate feedback to developers during code review, shifting security left in the development process."

## 📚 Additional Resources

- [Checkov Documentation](https://www.checkov.io/)
- [Checkov Policy Index](https://www.checkov.io/5.Policy%20Index/terraform.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

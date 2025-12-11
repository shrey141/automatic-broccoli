.PHONY: help test build run clean tf-init tf-plan tf-apply tf-destroy scan-container scan-deps lint format version bootstrap-common destroy-common

# Default environment
ENV ?= dev
AWS_REGION ?= us-east-1

help: ## Show this help message
	@echo "\n\033[1mAvailable commands:\033[0m\n"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Application

test: ## Run application tests with coverage
	@echo "\033[1;34m→ Running tests...\033[0m"
	cd app && pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html

lint: ## Lint Python code
	@echo "\033[1;34m→ Linting code...\033[0m"
	cd app && flake8 src/ tests/

format: ## Format Python code with black
	@echo "\033[1;34m→ Formatting code...\033[0m"
	cd app && black src/ tests/

format-check: ## Check if code needs formatting
	@echo "\033[1;34m→ Checking code format...\033[0m"
	cd app && black --check src/ tests/

build: ## Build Docker image locally
	@echo "\033[1;34m→ Building Docker image...\033[0m"
	cd app && docker build -t demo-app:latest .

run: ## Run application locally in Docker
	@echo "\033[1;34m→ Running application locally on port 8080...\033[0m"
	cd app && docker run --rm -p 8080:8080 \
		-e ENVIRONMENT=dev \
		-e ENABLE_CLOUDWATCH=false \
		demo-app:latest

run-dev: ## Run application in development mode
	@echo "\033[1;34m→ Running application in dev mode...\033[0m"
	cd app && FLASK_ENV=development python3 -m src.app

##@ Infrastructure

tf-init: ## Initialize Terraform for specified environment (ENV=dev|staging|prod|common)
	@echo "\033[1;34m→ Initializing Terraform for $(ENV) environment...\033[0m"
	cd terraform/environments/$(ENV) && terraform init

tf-plan: ## Plan Terraform changes (ENV=dev|staging|prod|common)
	@echo "\033[1;34m→ Planning Terraform changes for $(ENV) environment...\033[0m"
	cd terraform/environments/$(ENV) && terraform plan -out=tfplan

tf-apply: ## Apply Terraform changes (ENV=dev|staging|prod|common)
	@echo "\033[1;34m→ Applying Terraform changes for $(ENV) environment...\033[0m"
	cd terraform/environments/$(ENV) && terraform apply tfplan

tf-destroy: ## Destroy Terraform infrastructure (ENV=dev|staging|prod|common)
	@echo "\033[1;31m⚠️  WARNING: This will destroy all infrastructure in $(ENV) environment!\033[0m"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	cd terraform/environments/$(ENV) && terraform destroy

tf-output: ## Show Terraform outputs (ENV=dev|staging|prod|common)
	@cd terraform/environments/$(ENV) && terraform output

tf-fmt: ## Format all Terraform files
	@echo "\033[1;34m→ Formatting Terraform files...\033[0m"
	terraform fmt -recursive terraform/

##@ Security

scan-container: ## Scan Docker image for vulnerabilities
	@echo "\033[1;34m→ Scanning container for vulnerabilities...\033[0m"
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image demo-app:latest

scan-deps: ## Scan Python dependencies for security issues
	@echo "\033[1;34m→ Scanning dependencies...\033[0m"
	cd app && safety check -r requirements.txt
	cd app && bandit -r src/

scan-iac: ## Scan infrastructure code (requires checkov)
	@echo "\033[1;34m→ Scanning infrastructure code...\033[0m"
	checkov -d terraform/ --quiet || true

##@ Monitoring
#
# NOTE: Application deployments must be done via GitHub Actions (app-cd.yml).
# Infrastructure changes must be done via GitHub Actions (terraform-deploy.yml).
# This enforces proper CI/CD practices and prevents manual deployments.
#

logs: ## Tail CloudWatch logs (ENV=dev|staging|prod)
	@echo "\033[1;34m→ Tailing logs from $(ENV) environment...\033[0m"
	$(eval LOG_GROUP := $(shell cd terraform/environments/$(ENV) && terraform output -raw log_group_name))
	aws logs tail $(LOG_GROUP) --follow --region $(AWS_REGION)

logs-recent: ## Show recent logs (last 10 minutes)
	@echo "\033[1;34m→ Showing recent logs from $(ENV) environment...\033[0m"
	$(eval LOG_GROUP := $(shell cd terraform/environments/$(ENV) && terraform output -raw log_group_name))
	aws logs tail $(LOG_GROUP) --since 10m --region $(AWS_REGION)

status: ## Show ECS service status (ENV=dev|staging|prod)
	@echo "\033[1;34m→ Checking service status in $(ENV) environment...\033[0m"
	$(eval CLUSTER := $(shell cd terraform/environments/$(ENV) && terraform output -raw ecs_cluster_name))
	$(eval SERVICE := $(shell cd terraform/environments/$(ENV) && terraform output -raw ecs_service_name))
	aws ecs describe-services \
		--cluster $(CLUSTER) \
		--services $(SERVICE) \
		--region $(AWS_REGION) \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
		--output table

url: ## Get application URL (ENV=dev|staging|prod)
	@cd terraform/environments/$(ENV) && terraform output alb_url

open: ## Open application in browser (ENV=dev|staging|prod)
	@$(eval URL := $(shell cd terraform/environments/$(ENV) && terraform output -raw alb_url))
	@echo "\033[1;34m→ Opening $(URL) in browser...\033[0m"
	@open $(URL)/api/hello || xdg-open $(URL)/api/hello

##@ Utilities

clean: ## Clean build artifacts and caches
	@echo "\033[1;34m→ Cleaning build artifacts...\033[0m"
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf app/htmlcov app/.coverage app/.pytest_cache 2>/dev/null || true
	rm -rf terraform/environments/*/tfplan terraform/environments/*/.terraform 2>/dev/null || true
	@echo "\033[1;32m✓ Cleanup complete\033[0m"

setup: ## Setup development environment
	@echo "\033[1;34m→ Setting up development environment...\033[0m"
	cd app && python3 -m venv venv
	cd app && . venv/bin/activate && pip install -r requirements-dev.txt
	@echo "\033[1;32m✓ Setup complete! Activate with: cd app && source venv/bin/activate\033[0m"

version: ## Show current application version from pyproject.toml
	@grep '^version = ' app/pyproject.toml | cut -d'"' -f2

bootstrap-common: ## Bootstrap common infrastructure (ECR, OIDC, S3) - ONE TIME ONLY
	@echo "\033[1;34m→ Bootstrapping common infrastructure (ECR, OIDC, State bucket)...\033[0m"
	@echo "\033[1;33m⚠️  This should only be run ONCE to set up shared resources\033[0m"
	$(MAKE) tf-init ENV=common
	$(MAKE) tf-plan ENV=common
	@echo "\033[1;33m→ Review the plan above. Press ENTER to apply or Ctrl+C to cancel\033[0m"
	@read dummy
	$(MAKE) tf-apply ENV=common
	@echo "\033[1;32m✓ Common resources deployed!\033[0m"
	@echo ""
	@echo "\033[1;33mNext steps:\033[0m"
	@echo "  1. Verify OIDC role ARN matches GitHub secret AWS_ROLE_ARN"
	@echo "  2. Use GitHub Actions to deploy infrastructure:"
	@echo "     - Push terraform changes to trigger terraform-deploy.yml"
	@echo "     - Or manually trigger via GitHub UI"
	@echo "  3. Use GitHub Actions to deploy application:"
	@echo "     - Push app changes to trigger app-cd.yml"
	@echo "     - Or manually trigger via GitHub UI"

destroy-common: ## Destroy common infrastructure (ECR, OIDC, S3) - DESTRUCTIVE!
	@echo "\033[1;31m⚠️  WARNING: This will destroy ALL common infrastructure!\033[0m"
	@echo "\033[1;31m⚠️  This includes:\033[0m"
	@echo "\033[1;31m    - ECR repository and all container images\033[0m"
	@echo "\033[1;31m    - OIDC provider and IAM role for GitHub Actions\033[0m"
	@echo "\033[1;31m    - S3 bucket for Terraform state\033[0m"
	@echo ""
	@echo "\033[1;33m→ Make sure all environments (dev/staging/prod) are destroyed first!\033[0m"
	@echo "\033[1;33m→ Type 'destroy-common' to confirm, or press Ctrl+C to cancel:\033[0m"
	@read confirmation; \
	if [ "$$confirmation" != "destroy-common" ]; then \
		echo "\033[1;31m✗ Confirmation failed. Aborting.\033[0m"; \
		exit 1; \
	fi
	$(MAKE) tf-init ENV=common
	@echo "\033[1;34m→ Planning destruction of common infrastructure...\033[0m"
	cd terraform/environments/common && terraform plan -destroy -out=tfplan
	@echo ""
	@echo "\033[1;33m→ Review the destruction plan above. Press ENTER to destroy or Ctrl+C to cancel\033[0m"
	@read dummy
	cd terraform/environments/common && terraform apply tfplan
	@echo "\033[1;32m✓ Common infrastructure destroyed!\033[0m"


.PHONY: help test build run clean deploy tf-init tf-plan tf-apply tf-destroy scan-container scan-deps lint format

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

##@ Deployment

deploy-image: ## Build and push Docker image to ECR
	@echo "\033[1;34m→ Building and pushing image to ECR...\033[0m"
	$(eval ECR_REPO := $(shell cd terraform/environments/$(ENV) && terraform output -raw ecr_repository_url))
	$(eval AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	@echo "ECR Repository: $(ECR_REPO)"
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	cd app && docker build -t demo-app:latest .
	docker tag demo-app:latest $(ECR_REPO):latest
	docker tag demo-app:latest $(ECR_REPO):$(shell cat VERSION)
	docker push $(ECR_REPO):latest
	docker push $(ECR_REPO):$(shell cat VERSION)

deploy-service: ## Deploy new version to ECS (ENV=dev|staging|prod)
	@echo "\033[1;34m→ Deploying to ECS $(ENV) environment...\033[0m"
	$(eval CLUSTER := $(shell cd terraform/environments/$(ENV) && terraform output -raw ecs_cluster_name))
	$(eval SERVICE := $(shell cd terraform/environments/$(ENV) && terraform output -raw ecs_service_name))
	aws ecs update-service \
		--cluster $(CLUSTER) \
		--service $(SERVICE) \
		--force-new-deployment \
		--region $(AWS_REGION)
	@echo "\033[1;32m✓ Deployment initiated. Waiting for service to stabilize...\033[0m"
	aws ecs wait services-stable \
		--cluster $(CLUSTER) \
		--services $(SERVICE) \
		--region $(AWS_REGION)
	@echo "\033[1;32m✓ Service deployed successfully!\033[0m"

deploy: deploy-image deploy-service ## Full deployment: build, push, and deploy

deploy-common: ## Deploy common configuration to AWS
	@echo "\033[1;34m→ Deploying common configuration...\033[0m"
	$(MAKE) tf-init ENV=common
	$(MAKE) tf-plan ENV=common
	$(MAKE) tf-apply ENV=common

##@ Monitoring

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

version: ## Show current version
	@cat VERSION

bootstrap-backend: ## Create Terraform backend resources (S3 + DynamoDB)
	@echo "\033[1;34m→ Creating Terraform backend resources...\033[0m"
	$(eval AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	aws s3 mb s3://demo-app-terraform-state-$(AWS_ACCOUNT_ID) --region $(AWS_REGION) 2>/dev/null || true
	aws s3api put-bucket-versioning \
		--bucket demo-app-terraform-state-$(AWS_ACCOUNT_ID) \
		--versioning-configuration Status=Enabled
	aws dynamodb create-table \
		--table-name demo-app-terraform-locks \
		--attribute-definitions AttributeName=LockID,AttributeType=S \
		--key-schema AttributeName=LockID,KeyType=HASH \
		--billing-mode PAY_PER_REQUEST \
		--region $(AWS_REGION) 2>/dev/null || true
	@echo "\033[1;32m✓ Backend resources created\033[0m"
	@echo "\033[1;33m→ Update backend configuration in terraform/environments/*/main.tf\033[0m"

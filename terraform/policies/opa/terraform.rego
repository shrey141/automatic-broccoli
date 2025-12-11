# OPA Policy for Terraform - Custom Business Rules
# This policy enforces organizational standards beyond AWS best practices

package terraform.policies

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Default deny
default allow = false

# Allow if no violations
allow {
    count(deny) == 0
}

###########################################
# Required Tags Policy
###########################################

# All resources must have required tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] != "delete"

    # Check if resource supports tagging
    resource_supports_tags(resource.type)

    # Check for missing required tags
    missing_tags := required_tags - {tag | resource.change.after.tags[tag]}
    count(missing_tags) > 0

    msg := sprintf(
        "Resource '%s' (%s) is missing required tags: %v",
        [resource.address, resource.type, missing_tags]
    )
}

# Define required tags
required_tags := {
    "Environment",
    "Project",
    "ManagedBy"
}

# Resources that support tagging
resource_supports_tags(resource_type) {
    taggable_resources := {
        "aws_vpc",
        "aws_subnet",
        "aws_security_group",
        "aws_ecs_cluster",
        "aws_ecs_service",
        "aws_lb",
        "aws_lb_target_group",
        "aws_ecr_repository",
        "aws_cloudwatch_log_group",
        "aws_cloudwatch_dashboard",
        "aws_iam_role",
        "aws_s3_bucket"
    }
    resource_type in taggable_resources
}

###########################################
# ECS Task Definition Policy
###########################################

# ECS tasks must have CloudWatch logging configured
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ecs_task_definition"
    resource.change.actions[_] != "delete"

    container_definitions := json.unmarshal(resource.change.after.container_definitions)
    container := container_definitions[_]

    not has_cloudwatch_logging(container)

    msg := sprintf(
        "ECS task definition '%s' container '%s' must have CloudWatch logging configured",
        [resource.address, container.name]
    )
}

has_cloudwatch_logging(container) {
    container.logConfiguration.logDriver == "awslogs"
}

# ECS tasks must have memory limits
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ecs_task_definition"
    resource.change.actions[_] != "delete"

    not resource.change.after.memory

    msg := sprintf(
        "ECS task definition '%s' must specify memory limit",
        [resource.address]
    )
}

# ECS tasks must have CPU limits
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ecs_task_definition"
    resource.change.actions[_] != "delete"

    not resource.change.after.cpu

    msg := sprintf(
        "ECS task definition '%s' must specify CPU limit",
        [resource.address]
    )
}

###########################################
# Security Group Policy
###########################################

# Security groups must have descriptions
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    resource.change.actions[_] != "delete"

    description := resource.change.after.description
    not description

    msg := sprintf(
        "Security group '%s' must have a description",
        [resource.address]
    )
}

# Security groups should not allow unrestricted ingress on sensitive ports
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    resource.change.actions[_] != "delete"

    ingress := resource.change.after.ingress[_]
    ingress.cidr_blocks[_] == "0.0.0.0/0"

    sensitive_port := sensitive_ports[_]
    ingress.from_port <= sensitive_port
    ingress.to_port >= sensitive_port

    msg := sprintf(
        "Security group '%s' allows unrestricted access (0.0.0.0/0) on sensitive port %d",
        [resource.address, sensitive_port]
    )
}

sensitive_ports := {22, 3306, 5432, 6379, 27017}

###########################################
# ALB Policy
###########################################

# ALB must not be internal for this demo (we need public access)
# In real production, you might want internal ALBs
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lb"
    resource.change.actions[_] != "delete"

    # For this demo, we want public ALBs
    resource.change.after.internal == true
    contains(resource.change.after.name, "demo")

    msg := sprintf(
        "ALB '%s' for demo must be internet-facing (not internal)",
        [resource.address]
    )
}

###########################################
# CloudWatch Logs Policy
###########################################

# CloudWatch log groups should have retention policies
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_cloudwatch_log_group"
    resource.change.actions[_] != "delete"

    not resource.change.after.retention_in_days

    msg := sprintf(
        "CloudWatch log group '%s' must specify retention_in_days to prevent unlimited log storage costs",
        [resource.address]
    )
}

# Log retention should not exceed environment limits
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_cloudwatch_log_group"
    resource.change.actions[_] != "delete"

    retention := resource.change.after.retention_in_days
    environment := resource.change.after.tags.Environment

    max_retention := max_log_retention[environment]
    retention > max_retention

    msg := sprintf(
        "CloudWatch log group '%s' retention (%d days) exceeds maximum for %s environment (%d days)",
        [resource.address, retention, environment, max_retention]
    )
}

max_log_retention := {
    "dev": 7,
    "staging": 30,
    "prod": 365
}

###########################################
# IAM Policy
###########################################

# IAM roles should not have wildcard permissions
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_role_policy"
    resource.change.actions[_] != "delete"

    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]

    # Check for wildcard in Action
    statement.Action[_] == "*"

    msg := sprintf(
        "IAM policy '%s' should not use wildcard (*) in Action. Use specific permissions.",
        [resource.address]
    )
}

# IAM roles should not have wildcard resources (except for specific cases)
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_role_policy"
    resource.change.actions[_] != "delete"

    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]

    # Check for wildcard in Resource
    statement.Resource == "*"

    # Exclude CloudWatch metrics which often need wildcard
    not contains(lower(resource.address), "cloudwatch")
    not contains(lower(resource.address), "metrics")

    msg := sprintf(
        "IAM policy '%s' should not use wildcard (*) in Resource. Specify exact resources.",
        [resource.address]
    )
}

###########################################
# Naming Convention Policy
###########################################

# Resources should follow naming convention: {environment}-{service}-{resource-type}
deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] != "delete"

    # Check resources that have names
    resource.type in naming_enforced_resources

    name := resource.change.after.name
    environment := resource.change.after.tags.Environment

    # Name should start with environment
    not startswith(name, environment)

    msg := sprintf(
        "Resource '%s' name '%s' should start with environment prefix '%s-'",
        [resource.address, name, environment]
    )
}

naming_enforced_resources := {
    "aws_ecs_cluster",
    "aws_lb",
    "aws_cloudwatch_log_group"
}

###########################################
# Helper Functions
###########################################

lower(s) = result {
    result := lower(s)
}

startswith(string, prefix) {
    indexof(string, prefix) == 0
}

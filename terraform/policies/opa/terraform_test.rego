# OPA Policy Tests for Terraform

package terraform.policies

# Test required tags policy
test_required_tags_missing {
    deny["Resource 'aws_vpc.test' (aws_vpc) is missing required tags: {\"Environment\", \"ManagedBy\", \"Project\"}"] with input as {
        "resource_changes": [{
            "address": "aws_vpc.test",
            "type": "aws_vpc",
            "change": {
                "actions": ["create"],
                "after": {
                    "tags": {}
                }
            }
        }]
    }
}

test_required_tags_present {
    not deny[_] with input as {
        "resource_changes": [{
            "address": "aws_vpc.test",
            "type": "aws_vpc",
            "change": {
                "actions": ["create"],
                "after": {
                    "tags": {
                        "Environment": "dev",
                        "Project": "demo",
                        "ManagedBy": "terraform"
                    }
                }
            }
        }]
    }
}

# Test ECS CloudWatch logging policy
test_ecs_missing_cloudwatch_logs {
    msg := "ECS task definition 'aws_ecs_task_definition.test' container 'app' must have CloudWatch logging configured"
    msg in deny with input as {
        "resource_changes": [{
            "address": "aws_ecs_task_definition.test",
            "type": "aws_ecs_task_definition",
            "change": {
                "actions": ["create"],
                "after": {
                    "container_definitions": "[{\"name\":\"app\",\"image\":\"nginx\"}]",
                    "cpu": "256",
                    "memory": "512"
                }
            }
        }]
    }
}

# Test security group description
test_security_group_without_description {
    msg := "Security group 'aws_security_group.test' must have a description"
    msg in deny with input as {
        "resource_changes": [{
            "address": "aws_security_group.test",
            "type": "aws_security_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "name": "test-sg",
                    "tags": {
                        "Environment": "dev",
                        "Project": "demo",
                        "ManagedBy": "terraform"
                    }
                }
            }
        }]
    }
}

# Test log retention policy
test_cloudwatch_log_without_retention {
    msg := "CloudWatch log group 'aws_cloudwatch_log_group.test' must specify retention_in_days to prevent unlimited log storage costs"
    msg in deny with input as {
        "resource_changes": [{
            "address": "aws_cloudwatch_log_group.test",
            "type": "aws_cloudwatch_log_group",
            "change": {
                "actions": ["create"],
                "after": {
                    "name": "/test/logs",
                    "tags": {
                        "Environment": "dev",
                        "Project": "demo",
                        "ManagedBy": "terraform"
                    }
                }
            }
        }]
    }
}

# Test naming convention
test_resource_naming_convention {
    msg := "Resource 'aws_ecs_cluster.test' name 'wrong-name' should start with environment prefix 'dev-'"
    msg in deny with input as {
        "resource_changes": [{
            "address": "aws_ecs_cluster.test",
            "type": "aws_ecs_cluster",
            "change": {
                "actions": ["create"],
                "after": {
                    "name": "wrong-name",
                    "tags": {
                        "Environment": "dev",
                        "Project": "demo",
                        "ManagedBy": "terraform"
                    }
                }
            }
        }]
    }
}

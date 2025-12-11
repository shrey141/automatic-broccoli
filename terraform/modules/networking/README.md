# Networking Module

This module creates a production-ready AWS VPC with public and private subnets across multiple availability zones.

## Features

- VPC with configurable CIDR block
- Public subnets for load balancers
- Private subnets for application servers
- NAT Gateways for outbound internet access from private subnets
- Internet Gateway for public subnet access
- Route tables and associations
- Optional VPC Flow Logs for network traffic monitoring

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway = true

  tags = {
    Environment = "dev"
    Project     = "demo-app"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| vpc_cidr | CIDR block for VPC | string | 10.0.0.0/16 | no |
| availability_zones | List of AZs to use | list(string) | - | yes |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| enable_vpc_flow_logs | Enable VPC Flow Logs | bool | false | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_ids | List of NAT Gateway IDs |
| internet_gateway_id | Internet Gateway ID |

## Architecture

```
Internet
    |
    v
Internet Gateway
    |
    v
Public Subnets (ALB)
    |
    v
NAT Gateway
    |
    v
Private Subnets (ECS Tasks)
```

## Cost Considerations

- NAT Gateways are provisioned per AZ and incur hourly charges
- For dev environments, consider `enable_nat_gateway = false` or use a single NAT Gateway
- VPC Flow Logs incur CloudWatch Logs storage costs

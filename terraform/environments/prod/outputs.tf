output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ecr_repository_url" {
  description = "URL of the shared ECR repository"
  value       = data.aws_ecr_repository.demo_app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.ecs_service.log_group_name
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.observability.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.observability.sns_topic_arn
}

output "alarm_names" {
  description = "List of CloudWatch alarm names"
  value       = module.observability.alarm_names
}

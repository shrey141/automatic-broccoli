output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_security_group_id" {
  description = "ID of the ECS task security group"
  value       = aws_security_group.ecs_tasks.id
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "task_role_arn" {
  description = "ARN of the task IAM role"
  value       = aws_iam_role.ecs_task.arn
}

output "execution_role_arn" {
  description = "ARN of the task execution IAM role"
  value       = aws_iam_role.ecs_task_execution.arn
}

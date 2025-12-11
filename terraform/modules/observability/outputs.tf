output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "List of CloudWatch alarm names"
  value = concat(
    [aws_cloudwatch_metric_alarm.ecs_cpu_high.alarm_name],
    [aws_cloudwatch_metric_alarm.ecs_memory_high.alarm_name],
    [aws_cloudwatch_metric_alarm.service_down.alarm_name],
    aws_cloudwatch_metric_alarm.alb_target_5xx[*].alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_targets[*].alarm_name,
    aws_cloudwatch_metric_alarm.application_errors[*].alarm_name
  )
}

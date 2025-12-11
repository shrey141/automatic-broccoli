# CloudWatch observability: dashboards, alarms, and monitoring

data "aws_region" "current" {}

# CloudWatch Log Group (if not created by ECS service module)
# This is typically created by the ECS service module, but included here for reference

# SNS Topic for Alarms
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-${var.service_name}-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-${var.service_name}"

  dashboard_body = templatefile("${path.module}/dashboard.json", {
    region           = data.aws_region.current.name
    environment      = var.environment
    cluster_name     = var.ecs_cluster_name
    service_name     = var.ecs_service_name
    alb_arn_suffix   = try(split("/", var.alb_arn)[1], "")
    target_group_arn = try(split(":", var.target_group_arn)[5], "")
    log_group_name   = var.log_group_name
  })
}

# ECS Service CPU Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.environment}-${var.service_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "ECS service CPU utilization is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# ECS Service Memory Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.environment}-${var.service_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "ECS service memory utilization is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# ALB Target 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  count = var.alb_arn != "" ? 1 : 0

  alarm_name          = "${var.environment}-${var.service_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_rate_threshold
  alarm_description   = "ALB is receiving too many 5xx errors from targets"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = try(split("/", var.alb_arn)[1], "")
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# ALB Unhealthy Target Count
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  count = var.target_group_arn != "" ? 1 : 0

  alarm_name          = "${var.environment}-${var.service_name}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "One or more targets are unhealthy"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = try(split(":", var.target_group_arn)[5], "")
    LoadBalancer = try(split("/", var.alb_arn)[1], "")
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# ECS Task Count = 0 (Service Down)
resource "aws_cloudwatch_metric_alarm" "service_down" {
  alarm_name          = "${var.environment}-${var.service_name}-no-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ECS service has no running tasks"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# CloudWatch Log Metric Filter for Application Errors
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  count = var.log_group_name != "" ? 1 : 0

  name           = "${var.environment}-${var.service_name}-errors"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "CustomMetrics/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  count = var.log_group_name != "" ? 1 : 0

  alarm_name          = "${var.environment}-${var.service_name}-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApplicationErrors"
  namespace           = "CustomMetrics/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Application is logging too many errors"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

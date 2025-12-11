variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "demo-app"
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
  default     = ""
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarm (percentage)"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory utilization threshold for alarm (percentage)"
  type        = number
  default     = 85
}

variable "error_rate_threshold" {
  description = "5xx error count threshold"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

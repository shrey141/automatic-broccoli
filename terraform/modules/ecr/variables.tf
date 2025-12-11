variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "retention_count" {
  description = "Number of images to retain"
  type        = number
  default     = 10
}

variable "scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

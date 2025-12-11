output "role_arn" {
  description = "ARN of the OIDC Provider IAM Role"
  value       = module.oidc.role_arn
}

output "state_bucket_arn" {
  description = "The ARN of the Terraform state bucket"
  value       = module.tf_state.s3_bucket_arn
}

output "ecr_repository_url" {
  description = "URL of the shared ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the shared ECR repository"
  value       = module.ecr.repository_name
}

output "ecr_repository_arn" {
  description = "ARN of the shared ECR repository"
  value       = module.ecr.repository_arn
}

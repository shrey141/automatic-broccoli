output "role_arn" {
  description = "ARN of the OIDC Provider IAM Role"
  value       = module.oidc.role_arn
}

output "state_bucket_arn" {
  description = "The ARN of the Terraform state bucket"
  value       = module.tf_state.s3_bucket_arn
}

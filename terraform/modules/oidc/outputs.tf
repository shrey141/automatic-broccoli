
output "arn" {
  description = "The ARN of the OIDC provider."
  value       = aws_iam_openid_connect_provider.oidc_provider.arn
}

output "url" {
  description = "The URL of the OIDC provider."
  value       = aws_iam_openid_connect_provider.oidc_provider.url
}

output "role_arn" {
  description = "The ARN of the IAM role for GitHub Actions."
  value       = aws_iam_role.oidc_role.arn
}

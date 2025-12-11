
variable "url" {
  description = "The URL of the identity provider. Corresponds to the iss claim."
  type        = string
}

variable "client_id_list" {
  description = "A list of client IDs (also known as audiences)."
  type        = list(string)
}

variable "thumbprint_list" {
  description = "A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)."
  type        = list(string)
}

variable "role_name" {
  description = "Name for the IAM role."
  type        = string
  default     = "github-actions-role"
}

variable "github_owner" {
  description = "The GitHub organization or user."
  type        = string
}

variable "github_repo" {
  description = "The GitHub repository."
  type        = string
}

variable "branch_name" {
  description = "The git branch to allow."
  type        = string
  default     = "main"
}

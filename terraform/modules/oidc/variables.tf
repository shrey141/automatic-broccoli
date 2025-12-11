
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


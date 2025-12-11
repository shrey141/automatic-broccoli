
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url             = var.url
  client_id_list  = var.client_id_list
  thumbprint_list = var.thumbprint_list
}

data "aws_iam_policy_document" "github_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.branch_name}"]
    }
  }
}

resource "aws_iam_role" "oidc_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role_policy.json
}

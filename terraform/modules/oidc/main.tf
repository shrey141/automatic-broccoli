
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
      values   = ["repo:${var.github_owner}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "oidc_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role_policy.json
}

# IAM Policy for Terraform state access
data "aws_iam_policy_document" "terraform_state_policy" {
  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]
    resources = [
      "arn:aws:s3:::demo-app-terraform-state-files-per-env"
    ]
  }

  statement {
    sid    = "TerraformStateObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::demo-app-terraform-state-files-per-env/*"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_state_policy" {
  name   = "TerraformStateAccess"
  role   = aws_iam_role.oidc_role.id
  policy = data.aws_iam_policy_document.terraform_state_policy.json
}

# IAM Policy for AWS resource management
data "aws_iam_policy_document" "aws_resources_policy" {
  statement {
    sid    = "EC2AndVPCAccess"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECSAndECRAccess"
    effect = "Allow"
    actions = [
      "ecs:*",
      "ecr:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMAccess"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:PassRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchAccess"
    effect = "Allow"
    actions = [
      "logs:*",
      "cloudwatch:*",
      "sns:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ApplicationAutoScalingAccess"
    effect = "Allow"
    actions = [
      "application-autoscaling:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "STSAccess"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "aws_resources_policy" {
  name   = "AWSResourcesAccess"
  role   = aws_iam_role.oidc_role.id
  policy = data.aws_iam_policy_document.aws_resources_policy.json
}

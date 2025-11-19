locals {
  provider_alias = { for k, v in local.accounts :
    k => replace(replace(lower(k), " ", "_"), ".", "_")
  }
}

provider "aws" {
  for_each = { for key, account in local.accounts : key => account if length(account.github) > 0 }
  alias    = "oidc"
  region   = local.region_name

  assume_role {
    role_arn     = format(local.organization_role_arn_template, aws_organizations_account.this[each.key].id)
    session_name = "terraform-${replace(each.key, "/", "_")}"
  }
}

resource "aws_iam_openid_connect_provider" "this" {
  for_each = { for key, account in local.accounts : key => account if length(account.github) > 0 }
  provider = aws.oidc[each.key]

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.config.github_oidc_thumbprints
}

resource "aws_iam_role" "this" {
  for_each = { for key, account in local.accounts : key => account if length(account.github) > 0 }
  provider = aws.oidc[each.key]

  name = format("GitHubActionsRole-%s", local.provider_alias[each.key])

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.this.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = ["sts.amazonaws.com"]
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [for repo in each.value.github : format("repo:%s:*", repo)]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = aws_iam_role.this
  provider = aws.oidc[each.key]

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


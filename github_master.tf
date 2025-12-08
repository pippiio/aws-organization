resource "aws_iam_openid_connect_provider" "master" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.config.github_oidc_thumbprints
}

resource "aws_iam_role" "master" {
  name = format("GitHubActionsRole-%s", replace(replace(replace(lower(data.aws_organizations_organization.current.master_account_name), " ", "-"), ".", "-"), "/", "-"))

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.master.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = ["sts.amazonaws.com"]
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [format("repo:%s:*", var.config.master_account_github_repo)]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "master" {
  role       = aws_iam_role.master.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

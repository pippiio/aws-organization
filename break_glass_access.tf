resource "aws_iam_group" "break_glass_access" {
  name = "BreakGlassAccess"
  path = "/"
}

resource "aws_iam_group_policy_attachment" "break_glass_access" {
  group      = aws_iam_group.break_glass_access.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "break_glass_access" {
  statement {
    sid    = "BlockMostAccessUnlessSignedInWithMFA"
    effect = "Deny"
    not_actions = [
      "iam:ChangePassword",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ListUsers",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_group_policy" "break_glass_access" {
  name   = "RequireMultiFactorAuth"
  group  = aws_iam_group.break_glass_access.name
  policy = data.aws_iam_policy_document.break_glass_access.json
}

resource "aws_iam_user" "break_glass_access" {
  for_each = var.config.break_glass_accounts

  name = each.key
  path = "/"

  tags = local.default_tags
}

resource "aws_iam_group_membership" "break_glass_access" {
  name  = "break_glass_access"
  group = aws_iam_group.break_glass_access.name
  users = [for user in aws_iam_user.break_glass_access : user.name]
}

resource "aws_iam_user_login_profile" "break_glass_access" {
  for_each = var.config.break_glass_accounts

  user                    = aws_iam_user.break_glass_access[each.key].name
  password_length         = 20
  password_reset_required = true

  lifecycle {
    ignore_changes = [
      password_length,
      password_reset_required,
      pgp_key,
    ]
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "Enable IAM User Permissions"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }
  statement {
    sid       = "Allow Cloudtrail CloudWatch Logs"
    resources = ["*"]
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    principals {
      type        = "Service"
      identifiers = ["logs.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:*:${local.account_id}:log-group:${local.name_prefix}cloudtrail-logs"]
    }
  }
  statement {
    sid       = "Allow CloudTrail to encrypt logs"
    resources = ["*"]
    actions   = ["kms:GenerateDataKey*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = [for account in data.aws_organizations_organization.this.accounts : "arn:aws:cloudtrail:*:${account.id}:trail/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${local.region_name}:${local.account_id}:trail/${local.name_prefix}organization-cloudtrail"]
    }
  }
  statement {
    sid       = "Allow CloudTrail access"
    resources = ["*"]
    actions   = ["kms:DescribeKey"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${local.region_name}:${local.account_id}:trail/${local.name_prefix}organization-cloudtrail"]
    }
  }
  statement {
    sid       = "Allow CloudTrail to decrypt a trail"
    resources = ["*"]
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid       = "Allow Backup"
    resources = ["*"]
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    #   condition {
    #     test     = "ArnEquals"
    #     variable = "kms:EncryptionContext:aws:logs:arn"
    #     values   = ["arn:aws:logs:*:${local.account_id}:log-group:${local.name_prefix}cloudtrail-logs"]
    #   }
  }
  # ${data.aws_caller_identity.backup.id}
}

resource "aws_kms_key" "this" {
  description         = "KMS CMK used by ${var.name_prefix}organization"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms.json
  tags                = local.default_tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/organization"
  target_key_id = aws_kms_key.this.key_id
}

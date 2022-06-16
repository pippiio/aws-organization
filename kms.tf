data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "Enable IAM User Permissions"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.master_account_id}:root"]
    }
  }

  statement {
    sid       = "Allow CloudTrail to encrypt logs"
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${local.master_account_id}:key/*"]
    actions = [
      "kms:GenerateDataKey*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${local.master_account_id}:trail/${local.cloudtrail_name}"]
    }
  }

  statement {
    sid       = "Allow CloudTrail access"
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${local.master_account_id}:key/*"]
    actions = [
      "kms:DescribeKey",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${local.master_account_id}:trail/${local.cloudtrail_name}"]
    }
  }

  statement {
    sid       = "Enable CloudTrail log decrypt permissions"
    effect    = "Allow"
    resources = ["arn:aws:s3:::${local.cloudtrail_s3_name}"]
    actions = [
      "kms:Decrypt",
    ]

    principals {
      type        = "AWS"
      identifiers = [for a in aws_organizations_account.accounts : "arn:aws:iam::${a.id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"

      values = [data.aws_organizations_organization.organization.id]
    }

    condition {
      test     = "Null"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"

      values = ["false"]
    }
  }
}

resource "aws_kms_key" "cloudtrail" {
  description         = "KMS CMK used by organization cloudtrail."
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/organization-cloudtrail-kms-cmk"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

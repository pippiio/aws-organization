locals {
  log_archive_account_id = aws_organizations_account.this["security/Log archive"].id
}

data "aws_iam_policy_document" "log_archive_user" {
  statement {
    sid       = "AllowAssumeRole"
    actions   = ["sts:AssumeRole"]
    resources = [format(local.organization_role_arn_template, local.log_archive_account_id)]
  }
}

resource "aws_iam_user" "log_archive_user" {
  name          = "LogArchiveAssumer"
  path          = "/accounts/"
  force_destroy = true
  tags          = local.default_tags
}

resource "aws_iam_user_policy" "log_archive_user" {
  name   = "AssumeRole"
  user   = aws_iam_user.log_archive_user.name
  policy = data.aws_iam_policy_document.log_archive_user.json
}

resource "aws_iam_access_key" "log_archive_user" {
  user = aws_iam_user.log_archive_user.name
}

provider "aws" {
  alias      = "cloudtrail"
  region     = local.region_name
  access_key = aws_iam_access_key.log_archive_user.id
  secret_key = aws_iam_access_key.log_archive_user.secret
  assume_role {
    role_arn     = format(local.organization_role_arn_template, local.log_archive_account_id)
    session_name = "terraform-${terraform.workspace}"
  }
}

### Sub-account resources ### 

resource "aws_s3_bucket" "cloudtrail" {
  provider = aws.cloudtrail

  bucket = format("%scloudtrail-%s-%s",
    local.name_prefix,
    aws_organizations_account.this["security/Log archive"].id,
    local.region_name
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  provider = aws.cloudtrail

  bucket                  = aws_s3_bucket.cloudtrail.id
  ignore_public_acls      = true
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  provider = aws.cloudtrail

  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  provider = aws.cloudtrail

  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.this.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  provider = aws.cloudtrail

  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "180DaysRetentionRule"
    status = "Enabled"
    filter {}
    expiration {
      days = 180
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  provider = aws.cloudtrail

  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  provider = aws.cloudtrail

  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_s3.json
}

data "aws_iam_policy_document" "cloudtrail_s3" {
  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"
    resources = [
      aws_s3_bucket.cloudtrail.arn,
      "${aws_s3_bucket.cloudtrail.arn}/*"
    ]
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  statement {
    sid = "AWSBucketPermissionAndExistenceCheck"
    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.cloudtrail.arn]
    principals {
      type = "Service"
      identifiers = [
        "config.amazonaws.com",
        "cloudtrail.amazonaws.com",
      ]
    }
  }
  statement {
    sid       = "AWSBucketDeliveryForConfig"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/${data.aws_organizations_organization.this.id}/AWSLogs/*/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
  statement {
    sid     = "AWSBucketDeliveryForOrganizationTrail"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/${data.aws_organizations_organization.this.id}/AWSLogs/${local.account_id}/*",
      "${aws_s3_bucket.cloudtrail.arn}/${data.aws_organizations_organization.this.id}/AWSLogs/${data.aws_organizations_organization.this.id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

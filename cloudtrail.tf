data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:${local.account_id}:log-group:${local.name_prefix}cloudtrail-logs:*"]
  }
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
    resources = ["${aws_s3_bucket.cloudtrail.arn}/${aws_organizations_organization.this.id}/AWSLogs/*/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
  statement {
    sid     = "AWSBucketDeliveryForOrganizationTrail"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/${aws_organizations_organization.this.id}/AWSLogs/${local.account_id}/*",
      "${aws_s3_bucket.cloudtrail.arn}/${aws_organizations_organization.this.id}/AWSLogs/${aws_organizations_organization.this.id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "${local.name_prefix}cloudtrail-logs"
  kms_key_id        = aws_kms_key.this.arn
  retention_in_days = 14
  tags              = local.default_tags
}

resource "aws_iam_role" "cloudtrail" {
  name               = "${local.name_prefix}cloudtrail-role"
  description        = "AWS CloudTrail assumes this role to create and publish CloudTrail logs"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json
  path               = "/"

  inline_policy {
    name   = "${local.name_prefix}role"
    policy = data.aws_iam_policy_document.cloudtrail_cloudwatch.json
  }
}

resource "random_pet" "cloudtrail" {
  keepers = {
    account = local.region_name
    region  = local.account_id
    name    = local.name_prefix
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  provider = aws.log_archive
  bucket   = "${local.name_prefix}cloudtrail-${data.aws_caller_identity.log_archive.id}-${local.region_name}-${random_pet.cloudtrail.id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  provider                = aws.log_archive
  bucket                  = aws_s3_bucket.cloudtrail.id
  ignore_public_acls      = true
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.this.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.cloudtrail.id
  policy   = data.aws_iam_policy_document.cloudtrail_s3.json
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "180DaysRetentionRule"
    status = "Enabled"
    filter {}
    expiration {
      days = 180
    }
  }
}

resource "aws_cloudtrail" "cloudtrail" {
  name                          = "${local.name_prefix}organization-cloudtrail"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = aws_organizations_organization.this.id
  kms_key_id                    = aws_kms_key.this.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
}

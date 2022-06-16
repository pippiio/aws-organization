resource "aws_cloudtrail" "cloudtrail" {
  depends_on = [
    aws_s3_bucket_policy.cloudtrail
  ]

  name                          = local.cloudtrail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_s3_name

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.cloudtrail.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    effect    = "Allow"
    resources = [aws_s3_bucket.cloudtrail.arn]
    actions = [
      "s3:GetBucketAcl",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.master_account_id}/*"]
    actions = [
      "s3:PutObject",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_organizations_organization.organization.id}/*"]
    actions = [
      "s3:PutObject",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "versioning-bucket-config" {
  bucket = aws_s3_bucket.cloudtrail.bucket

  rule {
    id = "config"

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }

    dynamic "transition" {
      for_each = local.config.cloudtrail_180days_deep_archive == true ? [1] : []
      content {
        days          = 180
        storage_class = "DEEP_ARCHIVE"
      }
    }

    dynamic "expiration" {
      for_each = local.config.cloudtrail_180days_deep_archive == false ? [1] : []
      content {
        days = 180
      }
    }

    status = "Enabled"
  }
}
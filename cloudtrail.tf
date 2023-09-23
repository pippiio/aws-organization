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

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "${local.name_prefix}cloudtrail-logs"
  kms_key_id        = aws_kms_key.this.arn
  retention_in_days = 7
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

resource "aws_cloudtrail" "cloudtrail" {
  name                          = "${local.name_prefix}organization-cloudtrail"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = data.aws_organizations_organization.this.id
  kms_key_id                    = aws_kms_key.this.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true

  depends_on = [
    aws_s3_bucket_public_access_block.cloudtrail,
    aws_s3_bucket_versioning.cloudtrail,
    aws_s3_bucket_server_side_encryption_configuration.cloudtrail,
    aws_s3_bucket_policy.cloudtrail,
    aws_s3_bucket_ownership_controls.cloudtrail,
    aws_s3_bucket_lifecycle_configuration.cloudtrail,
  ]
}

resource "aws_cloudtrail_event_data_store" "this" {
  name                 = "${local.name_prefix}event-data-store"
  multi_region_enabled = true
  organization_enabled = true
  retention_period     = 6 * 30
  kms_key_id           = aws_kms_key.this.arn
  tags                 = local.default_tags
}

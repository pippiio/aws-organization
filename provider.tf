provider "aws" {
  region = local.region_name
  alias  = "log_archive"
  assume_role {
    role_arn     = "arn:aws:iam::${aws_organizations_account.log_archive.id}:role/${local.organization_role_name}"
    session_name = "terraform"
    external_id  = null
  }
}

data "aws_caller_identity" "log_archive" {
  provider = aws.log_archive
}

provider "aws" {
  region = "us-east-1"
  alias  = "backup"
  assume_role {
    role_arn     = "arn:aws:iam::${aws_organizations_account.backup.id}:role/${local.organization_role_name}"
    session_name = "terraform"
    external_id  = null
  }
}

data "aws_caller_identity" "backup" {
  provider = aws.backup
}

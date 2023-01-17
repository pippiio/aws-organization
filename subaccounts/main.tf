data "aws_organizations_organization" "this" {}

data "aws_caller_identity" "log_archive" {
  provider = aws.log_archive
}

# data "aws_caller_identity" "security_tooling" {
#   provider = aws.security_tooling
# }

# data "aws_caller_identity" "backup" {
#   provider = aws.backup
# }

# data "aws_caller_identity" "network" {
#   provider = aws.network
# }

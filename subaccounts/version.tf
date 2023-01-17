terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
      configuration_aliases = [
        aws.log_archive,
        # aws.security_tooling,
        # aws.backup,
        # aws.network,
      ]
    }
  }
}

terraform {
  required_version = "~>1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
  }
}

# Must be credentials in the AWS Organization management account.
provider "aws" {
  region = "eu-west-1"
}

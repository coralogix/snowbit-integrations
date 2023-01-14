terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17.1"
    }
  }
}
## When using for Route53 Log group
##      ||
##      \/
#provider "aws" {
#  region = "us-east-1"
#}

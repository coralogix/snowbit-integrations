terraform {
  required_version = ">= 0.13.1"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}
terraform {
  required_version = "~> 1.14.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
  backend "s3" {
    region = "eu-central-1"
    bucket = "terraform-state-bucket-500128174326"
    key    = "aws-infrastructure.tfstate"
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

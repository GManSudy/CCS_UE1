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
    bucket = "terraform-state-bucket-wurscht1"
    key    = "aws-infrastructure.tfstate"
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-name"
    values = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  }
}

data "aws_caller_identity" "current" {}

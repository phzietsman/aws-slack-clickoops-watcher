terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.49.0"
    }
  }
}

provider "aws" {
  alias  = "reference"
  region = var.region
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.mandatory_tags
  }
}
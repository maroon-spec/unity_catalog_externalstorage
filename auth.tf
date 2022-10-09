variable "databricks_connection_profile" {}
variable "aws_connection_profile" {}
variable "aws_region" {}

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Use AWS CLI authentication.
provider "aws" {
  profile = var.aws_connection_profile
  region = var.aws_region
}

# Use Databricks CLI authentication.
provider "databricks" {
  profile = var.databricks_connection_profile
}


# Generate a random string as the prefix for AWS resources, to ensure uniqueness.
resource "random_string" "naming" {
  special = false
  upper   = false
  length  = 6
}

locals {
  prefix = "demo${random_string.naming.result}"
  tags   = {}
}

# -------------------------------------------------------
# Terraform Providers Configuration
# AWS (primary compute) + GCP (storage)
# -------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# -------------------------------------------------------
# AWS Provider - Primary cloud for compute, CI/CD, networking
# -------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Assessment  = "DCE04.2-Assessment1"
    }
  }
}

# -------------------------------------------------------
# GCP Provider - Cloud Storage for application assets
# -------------------------------------------------------
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

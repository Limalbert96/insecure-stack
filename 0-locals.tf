# Project Configuration Variables
# This file contains global variables used throughout the infrastructure
# Testing automatic deployment workflow with manual approval gate

locals {
  # Basic GCP Project Configuration
  # All values now sourced from variables for security and flexibility
  # Pass via environment variables: TF_VAR_project_id, TF_VAR_region
  project_id = var.project_id
  region     = var.region

  # Required Google Cloud APIs
  # Security Note: Follow principle of least privilege
  # Only enable APIs that are actually needed
  apis = [
    "compute.googleapis.com",           # For VMs and networking
    "container.googleapis.com",         # For GKE
    "logging.googleapis.com",           # For centralized logging
    "secretmanager.googleapis.com",     # For secrets management
    "storage.googleapis.com",           # For GCS buckets
    "networkservices.googleapis.com",   # For network services
    "iamcredentials.googleapis.com",    # For IAM Service Account credentials
  ]

  # GitHub Configuration
  # Security Fix: All credentials now sourced from GitHub Actions secrets
  # Values passed as Terraform variables from the CI/CD pipeline
  # See variables.tf for variable definitions
  #
  # Production Best Practices:
  # 1. Use Secret Manager or secure CI/CD secrets
  # 2. Implement regular credential rotation
  # 3. Use workload identity when possible
  github_config = {
    username = var.github_username
    # PAT is now provided via variable (from GitHub Actions secrets)
    # Pass via: TF_VAR_github_pat environment variable
    pat = var.github_pat
  }
}

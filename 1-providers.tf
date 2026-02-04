# Provider Configuration
# This file configures the necessary providers for GCP and Kubernetes

# SECURITY RECOMMENDATIONS:
# 1. Use Workload Identity instead of service account keys
# 2. Enable provider-level constraints for resource creation
# 3. Implement least privilege access for service accounts
# 4. Use separate service accounts for different environments
# 5. Rotate credentials regularly
# 6. Enable audit logging for all provider actions

# Google Cloud Provider Configuration
# SECURITY RISK: Using default Application Default Credentials
# which may have overly broad permissions
provider "google" {
  project = local.project_id
  region  = local.region
  # MISSING: No provider-level constraints
  # RECOMMENDATION: Add constraints for:
  # - Allowed services
  # - Resource locations
  # - IAM role restrictions
}

# Kubernetes Provider Configuration
# SECURITY RISKS:
# 1. Using cluster admin token for all operations
# 2. No explicit service account configuration
# 3. Missing RBAC restrictions
provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  # RECOMMENDATIONS:
  # 1. Use dedicated service account with minimal permissions
  # 2. Implement pod security policies
  # 3. Enable network policies
  # 4. Use private endpoint access only
}

# Default GCP client configuration
# SECURITY RISK: Using default configuration which may be too permissive if used
# Used for OAuth token generation
data "google_client_config" "default" {}

# Terraform Configuration Block
# Defines version constraints and required providers
terraform {
  # Require Terraform 1.0 or higher
  # Security Note: Regular updates are important for security fixes
  required_version = ">= 1.0"

  required_providers {
    # Google Cloud Provider
    # Version ~> 6.0 includes important security updates
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }

    # Kubernetes Provider
    # Used for managing Kubernetes resources
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

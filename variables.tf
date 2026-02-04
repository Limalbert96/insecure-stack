# Terraform Variables
# This file defines input variables that must be provided at runtime

variable "github_pat" {
  description = "GitHub Personal Access Token for container registry authentication. This should be provided via GitHub Actions secrets, not hardcoded."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_pat) > 0
    error_message = "GitHub PAT must not be empty. Pass it via TF_VAR_github_pat environment variable or GitHub Actions secrets."
  }
}

variable "project_id" {
  description = "GCP Project ID. Provided via GitHub Actions secrets for security and flexibility."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty. Pass it via TF_VAR_project_id environment variable."
  }
}

variable "region" {
  description = "GCP region for resource deployment. Provided via GitHub Actions secrets for flexibility."
  type        = string

  validation {
    condition     = length(var.region) > 0
    error_message = "Region must not be empty. Pass it via TF_VAR_region environment variable."
  }
}

variable "github_username" {
  description = "GitHub username for container registry. Provided via GitHub Actions secrets."
  type        = string

  validation {
    condition     = length(var.github_username) > 0
    error_message = "GitHub username must not be empty. Pass it via TF_VAR_github_username environment variable."
  }
}

variable "project_number" {
  description = "GCP Project Number. Used for Workload Identity Federation. Provided via GitHub Actions secrets."
  type        = string

  validation {
    condition     = length(var.project_number) > 0
    error_message = "Project number must not be empty. Pass it via TF_VAR_project_number environment variable."
  }
}

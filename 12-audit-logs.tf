# IAM Audit Log Configuration
# Enables comprehensive audit logging for IAM-related activities

# Enable audit logging for all IAM changes and access
resource "google_project_iam_audit_config" "project" {
  project = local.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  
  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

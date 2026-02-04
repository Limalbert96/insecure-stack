# Cloud Armor Security Policy
resource "google_compute_security_policy" "tasky" {
  provider = google
  project  = local.project_id
  name     = "tasky-security-policy"

  # Rate limiting rule - 100 requests per minute per IP
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      conform_action   = "allow"
      exceed_action   = "deny(429)"
      enforce_on_key  = "IP"
      ban_duration_sec = 60  # 1-minute ban if exceeded
    }
    description = "Rate limiting rule - 100 requests per minute per IP"
  }

  # Default rule (required)
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, allows all traffic"
  }

  # Enable verbose logging
  advanced_options_config {
    log_level = "VERBOSE"
  }
}